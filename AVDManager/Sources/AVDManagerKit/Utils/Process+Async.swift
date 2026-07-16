import Foundation

/// Thread-safe line buffer used by streaming process runner.
final class LineBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()
    private let newline = Data([0x0A])

    /// Appends incoming data and returns any complete lines extracted.
    func append(_ incoming: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        data.append(incoming)
        var lines: [String] = []
        while let range = data.range(of: newline) {
            let lineData = data.subdata(in: 0..<range.lowerBound)
            data.removeSubrange(0..<range.upperBound)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
        }
        return lines
    }

    /// Drains any remaining bytes as a single line.
    func drain() -> String? {
        lock.lock()
        defer { lock.unlock() }
        defer { data.removeAll() }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Thread-safe data accumulator used by the non-streaming process runner.
private final class DataBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ incoming: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(incoming)
    }

    func string() -> String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

/// Async wrapper around `Process` that supports cancellation via `SIGTERM`.
public enum ProcessRunner {
    public static func run(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        input: Data? = nil
    ) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = try makeProcess(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory
        )
        return try await execute(process: process, input: input)
    }

    public static func runWithCancellation(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        input: Data? = nil
    ) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = try makeProcess(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory
        )
        let reference = ProcessReference()
        reference.process = process
        return try await withTaskCancellationHandler {
            try await execute(process: process, input: input)
        } onCancel: {
            reference.process?.terminate()
        }
    }

    public static func runStreaming(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        lineHandler: @Sendable @escaping (String) -> Void
    ) async throws -> Int32 {
        let process = try makeProcess(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory
        )
        return try await executeStreaming(process: process, lineHandler: lineHandler)
    }

    public static func runStreamingWithCancellation(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        lineHandler: @Sendable @escaping (String) -> Void
    ) async throws -> Int32 {
        let process = try makeProcess(
            executable: executable,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory
        )
        let reference = ProcessReference()
        reference.process = process
        return try await withTaskCancellationHandler {
            try await executeStreaming(process: process, lineHandler: lineHandler)
        } onCancel: {
            reference.process?.terminate()
        }
    }
}

private extension ProcessRunner {
    static func resolveExecutable(_ executable: String, environment: [String: String]?) throws -> String {
        if executable.hasPrefix("/") || executable.hasPrefix("./") {
            return executable
        }
        if executable.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return executable.replacingOccurrences(of: "~", with: home)
        }

        let pathEnv = environment?["PATH"]
            ?? ProcessInfo.processInfo.environment["PATH"]
            ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let paths = pathEnv.split(separator: ":").map(String.init)
        if let found = paths.lazy
            .map({ URL(fileURLWithPath: $0).appendingPathComponent(executable).path })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }
        throw AVDManagerError.executableNotFound(executable)
    }

    static func makeProcess(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: URL?
    ) throws -> Process {
        let resolved = try resolveExecutable(executable, environment: environment)
        guard FileManager.default.isExecutableFile(atPath: resolved) else {
            throw AVDManagerError.executableNotFound(resolved)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolved)
        process.arguments = arguments
        if let environment = environment {
            process.environment = environment
        }
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = workingDirectory
        }
        return process
    }

    static func execute(process: Process, input: Data?) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let stdoutBuffer = DataBuffer()
        let stderrBuffer = DataBuffer()

        return try await withCheckedThrowingContinuation { continuation in
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                stdoutBuffer.append(data)
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                stderrBuffer.append(data)
            }

            process.terminationHandler = { _ in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                continuation.resume(returning: (
                    stdoutBuffer.string(),
                    stderrBuffer.string(),
                    process.terminationStatus
                ))
            }

            do {
                if let input = input, !input.isEmpty {
                    let stdinPipe = Pipe()
                    process.standardInput = stdinPipe
                    try process.run()
                    stdinPipe.fileHandleForWriting.write(input)
                    stdinPipe.fileHandleForWriting.closeFile()
                } else {
                    try process.run()
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static func executeStreaming(
        process: Process,
        lineHandler: @Sendable @escaping (String) -> Void
    ) async throws -> Int32 {
        let stdoutBuffer = LineBuffer()
        let stderrBuffer = LineBuffer()

        return try await withCheckedThrowingContinuation { continuation in
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                for line in stdoutBuffer.append(data) {
                    lineHandler(line)
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                for line in stderrBuffer.append(data) {
                    lineHandler(line)
                }
            }

            process.terminationHandler = { _ in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                if let line = stdoutBuffer.drain(), !line.isEmpty {
                    lineHandler(line)
                }
                if let line = stderrBuffer.drain(), !line.isEmpty {
                    lineHandler(line)
                }
                continuation.resume(returning: process.terminationStatus)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class ProcessReference: @unchecked Sendable {
    private var _process: Process?
    private let lock = NSLock()

    var process: Process? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _process
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _process = newValue
        }
    }
}
