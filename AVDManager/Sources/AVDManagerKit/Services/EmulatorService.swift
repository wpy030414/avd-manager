import Foundation

public actor EmulatorService {
    private let sdk: AndroidSDK
    private var runningProcesses: [String: Process] = [:]

    public init(sdk: AndroidSDK) {
        self.sdk = sdk
    }

    // MARK: - Start

    /// Find a free port pair (console, adb) starting from basePort.
    private func findFreePort(basePort: Int = 5554) async -> Int {
        let env = await sdk.environmentForSubprocess()
        guard let adb = await sdk.adbPath else { return basePort }

        // Poll existing devices to avoid conflicts
        let result = try? await ProcessRunner.run(adb, arguments: ["devices"], environment: env)
        let usedPorts = (result?.stdout ?? "")
            .components(separatedBy: .newlines)
            .filter { $0.contains("emulator-") }
            .compactMap { line -> Int? in
                guard let range = line.range(of: "emulator-") else { return nil }
                let portStr = line[range.upperBound...]
                    .components(separatedBy: .whitespaces).first ?? ""
                return Int(portStr)
            }

        var port = basePort
        while usedPorts.contains(port) { port += 2 }
        return port
    }

    public func start(
        _ avd: AVD,
        settings: EmulatorLaunchSettings = .init(),
        onLog: (@Sendable (String) -> Void)? = nil
    ) async throws -> (process: Process, port: Int) {
        guard let emulatorPath = await sdk.emulatorPath else {
            DebugLog.log("ERROR: emulatorPath is nil! sdkRoot=\(await sdk.sdkRootPath ?? "nil")")
            throw AVDManagerError.missingSDK
        }
        DebugLog.log("emulatorPath=\(emulatorPath), avd=\(avd.name)")
        let env = await sdk.environmentForSubprocess()
        let port = await findFreePort()
        DebugLog.log("using port=\(port)")

        // Sync hw.keyboard in config.ini to match keyboard forwarding setting
        applyKeyboardConfig(avdName: avd.name, enableKeyboard: settings.enableKeyboard)

        var args = ["-avd", avd.name, "-port", String(port)]
        args.append(contentsOf: settings.arguments)
        DebugLog.log("args=\(args)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: emulatorPath)
        process.arguments = args
        process.environment = env

        if let onLog {
            // Stream emulator stdout + stderr to the log UI line by line.
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let lineBuffer = LineBuffer()
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                for line in lineBuffer.append(data) {
                    onLog(line)
                }
            }
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                for line in lineBuffer.append(data) {
                    onLog(line)
                }
            }
            process.terminationHandler = { _ in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                if let line = lineBuffer.drain(), !line.isEmpty {
                    onLog(line)
                }
            }
        } else {
            // Fallback: redirect stderr to temp file for crash debugging.
            let errURL = URL(fileURLWithPath: "/tmp/avdmanager-emu-err.log")
            FileManager.default.createFile(atPath: errURL.path, contents: nil)
            if let errFH = try? FileHandle(forWritingTo: errURL) {
                process.standardError = errFH
            }
            process.standardOutput = FileHandle.nullDevice
        }

        try process.run()
        DebugLog.log("emulator process launched pid=\(process.processIdentifier)")
        runningProcesses[avd.name] = process
        return (process, port)
    }

    /// Update hw.keyboard in the AVD's config.ini to match keyboard forwarding settings.
    private func applyKeyboardConfig(avdName: String, enableKeyboard: Bool) {
        let avdPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".android/avd/\(avdName).avd/config.ini")
        let path = avdPath.path
        guard FileManager.default.fileExists(atPath: path) else { return }

        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }

        let currentValue = content.contains("hw.keyboard=yes")
        let targetValue = enableKeyboard

        if currentValue == targetValue { return }  // Already correct

        let newContent = content.replacingOccurrences(
            of: "hw.keyboard=\(currentValue ? "yes" : "no")",
            with: "hw.keyboard=\(targetValue ? "yes" : "no")"
        )
        try? newContent.write(toFile: path, atomically: true, encoding: .utf8)
        DebugLog.log("config.ini hw.keyboard set to \(targetValue ? "yes" : "no")")
    }

    // MARK: - Stop

    public func stop(_ avd: AVD) async throws {
        let env = await sdk.environmentForSubprocess()

        // If we started this process, terminate it directly
        if let process = runningProcesses[avd.name] {
            process.terminate()
            runningProcesses.removeValue(forKey: avd.name)
            // Also send emu kill via adb if possible
            if let port = avd.consolePort, let adb = await sdk.adbPath {
                _ = try? await ProcessRunner.run(
                    adb, arguments: ["-s", "emulator-\(port)", "emu", "kill"], environment: env
                )
            }
            return
        }

        // Emulator started externally — find its console port and kill via adb
        if let port = try? await findConsolePort(for: avd.name), let adb = await sdk.adbPath {
            _ = try? await ProcessRunner.run(
                adb, arguments: ["-s", "emulator-\(port)", "emu", "kill"], environment: env
            )
            return
        }

        // Last resort: find and kill qemu process by AVD name
        let script = "ps -eo pid,command | grep -i 'qemu.*-avd \(avd.name)' | grep -v grep | awk '{print $1}'"
        let result = try? await ProcessRunner.run("/bin/sh", arguments: ["-c", script], environment: env)
        let pids = (result?.stdout ?? "")
            .split(separator: "\n")
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
        for pid in pids {
            kill(pid, SIGTERM)
        }

        if pids.isEmpty {
            throw AVDManagerError.subprocessFailed(exitCode: -1, stderr: "No running emulator found for AVD '\(avd.name)'")
        }
    }

    // MARK: - State Refresh (adb-based)

    /// Represents a running emulator discovered via `adb devices`.
    private struct RunningEmulator: Sendable {
        let serial: String       // e.g. "emulator-5554"
        let consolePort: Int     // e.g. 5554
        let avdName: String?
        let bootCompleted: Bool
        let isOnline: Bool       // false = still connecting (offline)
    }

    /// Discover all running emulators via `adb devices`.
    private func discoverRunningEmulators() async -> [RunningEmulator] {
        let env = await sdk.environmentForSubprocess()
        guard let adb = await sdk.adbPath else {
            DebugLog.log("discoverRunningEmulators: no adb path")
            return []
        }

        guard let (stdout, _, _) = try? await ProcessRunner.run(
            adb, arguments: ["devices"], environment: env
        ) else {
            DebugLog.log("discoverRunningEmulators: adb devices failed")
            return []
        }

        // Parse serial + state from `adb devices` output lines like:
        //   emulator-5554   device
        //   emulator-5556   offline
        let deviceLines = stdout
            .components(separatedBy: .newlines)
            .filter { $0.contains("emulator-") }

        DebugLog.log("discoverRunningEmulators: found \(deviceLines.count) emulator lines: \(deviceLines)")

        var emulators: [RunningEmulator] = []
        for line in deviceLines {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 2,
                  let serial = parts.first, serial.hasPrefix("emulator-") else { continue }

            let state = parts[1]  // "device", "offline", "unauthorized"
            let portStr = serial.replacingOccurrences(of: "emulator-", with: "")
            guard let port = Int(portStr) else { continue }

            // Try to get AVD name (multiple strategies)
            let avdName = await resolveAvdName(serial: serial, adb: adb, env: env)

            // Check boot status (only if device is online)
            var booted = false
            if state == "device" {
                let bootResult = try? await ProcessRunner.run(
                    adb, arguments: ["-s", serial, "shell", "getprop", "sys.boot_completed"], environment: env
                )
                let bootRaw = bootResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) ?? "nil"
                booted = bootRaw == "1"
                DebugLog.log("discoverRunningEmulators: serial=\(serial) avdName=\(avdName ?? "nil") bootCompleted=\(bootRaw) booted=\(booted)")
            }

            emulators.append(RunningEmulator(
                serial: serial,
                consolePort: port,
                avdName: avdName,
                bootCompleted: booted,
                isOnline: state == "device"
            ))
        }

        return emulators
    }

    /// Try multiple strategies to resolve an emulator's AVD name from its serial.
    private func resolveAvdName(serial: String, adb: String, env: [String: String]) async -> String? {
        // Strategy 1: `adb emu avd name` returns "name\nOK\n" — take the first line.
        let emuResult = try? await ProcessRunner.run(
            adb, arguments: ["-s", serial, "emu", "avd", "name"], environment: env
        )
        if let raw = emuResult?.stdout {
            let lines = raw.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
            DebugLog.log("resolveAvdName: serial=\(serial) emu avd name raw lines=\(lines)")
            let firstLine = lines.first(where: { !$0.isEmpty && $0 != "OK" }) ?? ""
            if !firstLine.isEmpty, !firstLine.hasPrefix("KO:") {
                return firstLine
            }
        }

        // Strategy 2: `adb shell getprop ro.kernel.qemu.avd_name` (kernel cmdline)
        let propResult = try? await ProcessRunner.run(
            adb, arguments: ["-s", serial, "shell", "getprop", "ro.kernel.qemu.avd_name"], environment: env
        )
        if let name = propResult?.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            DebugLog.log("resolveAvdName: serial=\(serial) getprop result=\(name)")
            return name
        }

        DebugLog.log("resolveAvdName: serial=\(serial) FAILED to resolve name")
        return nil  // Could not determine name — caller matches by port
    }

    /// Normalize an AVD name for fuzzy comparison (spaces ↔ underscores).
    private func normalizedName(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
    }

    /// Match a known AVD against a running emulator, by name first then by port.
    private func matchAVD(_ avd: AVD, against emulators: [RunningEmulator]) -> RunningEmulator? {
        let norm = normalizedName(avd.name)

        // 1. Exact name match
        if let match = emulators.first(where: { emu in
            guard let name = emu.avdName else { return false }
            return name == avd.name || normalizedName(name) == norm
        }) {
            DebugLog.log("matchAVD: '\(avd.name)' matched by name")
            return match
        }

        // 2. Port match (we started this emulator and know its port)
        if let port = avd.consolePort {
            if let match = emulators.first(where: { $0.consolePort == port }) {
                DebugLog.log("matchAVD: '\(avd.name)' matched by port \(port)")
                return match
            }
        }

        // 3. Process match: we started this AVD, and there's an emulator
        //    with an unresolved name — assume it's ours.
        if runningProcesses[avd.name] != nil {
            let unmatched = emulators.filter { $0.avdName == nil }
            if unmatched.count == 1 {
                DebugLog.log("matchAVD: '\(avd.name)' matched by process (1 unresolved emu)")
                return unmatched.first
            }
            if let fallback = unmatched.first {
                DebugLog.log("matchAVD: '\(avd.name)' matched by process (fallback)")
                return fallback
            }
        }

        DebugLog.log("matchAVD: '\(avd.name)' NO MATCH (avd.consolePort=\(avd.consolePort.map(String.init) ?? "nil") runningProcesses=\(runningProcesses[avd.name] != nil ? "yes" : "no") emulators=\(emulators.map { "\($0.serial) name=\($0.avdName ?? "nil")" }))")
        return nil
    }

    /// Find the console port for a given AVD name by scanning running emulators.
    private func findConsolePort(for avdName: String) async throws -> Int {
        let emulators = await discoverRunningEmulators()
        let norm = normalizedName(avdName)
        guard let emu = emulators.first(where: { emu in
            guard let name = emu.avdName else { return false }
            return normalizedName(name) == norm
        }) else {
            throw AVDManagerError.subprocessFailed(exitCode: -1, stderr: "Emulator '\(avdName)' not found")
        }
        return emu.consolePort
    }

    public func refreshStates(for avds: [AVD]) async -> [AVD] {
        let running = await discoverRunningEmulators()
        var updated = avds
        DebugLog.log("refreshStates: \(avds.count) avds, \(running.count) running emulators")

        for i in updated.indices {
            let avd = updated[i]

            if let emu = matchAVD(avd, against: running) {
                DebugLog.log("refreshStates: '\(avd.name)' matched emu name=\(emu.avdName ?? "nil") port=\(emu.consolePort) online=\(emu.isOnline) booted=\(emu.bootCompleted)")
                if emu.isOnline {
                    updated[i].state = emu.bootCompleted ? .running : .booting
                } else {
                    updated[i].state = .booting
                }
                updated[i].consolePort = emu.consolePort
            } else if let process = runningProcesses[avd.name], process.isRunning {
                updated[i].state = .booting
                DebugLog.log("refreshStates: '\(avd.name)' NO MATCH (process running, waiting for ADB)")
            } else {
                runningProcesses.removeValue(forKey: avd.name)
                updated[i].state = .stopped
                updated[i].consolePort = nil
                DebugLog.log("refreshStates: '\(avd.name)' → stopped (no running emulator)")
            }
        }

        DebugLog.log("refreshStates result: \(updated.map { "\($0.name)=\($0.state.rawValue)" })")
        return updated
    }

    /// Poll until the AVD reaches the "running" (boot completed) state.
    public func waitForBoot(avdName: String, timeoutSeconds: Double = 120) async throws {
        guard await sdk.adbPath != nil else { throw AVDManagerError.missingSDK }

        let norm = normalizedName(avdName)
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        var attempt = 0
        while Date() < deadline {
            attempt += 1
            let emulators = await discoverRunningEmulators()
            if let emu = emulators.first(where: { emu in
                guard let name = emu.avdName else { return false }
                return normalizedName(name) == norm
            }) {
                DebugLog.log("waitForBoot: attempt \(attempt) found emu for '\(avdName)', bootCompleted=\(emu.bootCompleted)")
                if emu.bootCompleted {
                    DebugLog.log("waitForBoot: '\(avdName)' boot completed!")
                    return
                }
            } else {
                DebugLog.log("waitForBoot: attempt \(attempt) no match for '\(avdName)' norm=\(norm)")
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        DebugLog.log("waitForBoot: TIMEOUT for '\(avdName)'")
        throw AVDManagerError.subprocessFailed(exitCode: -1, stderr: "Timed out waiting for AVD '\(avdName)' to boot")
    }
}
