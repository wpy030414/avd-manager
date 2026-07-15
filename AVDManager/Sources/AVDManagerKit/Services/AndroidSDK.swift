import Foundation
import Combine

// MARK: - Dependency Status

public struct DependencyStatus: Sendable {
    public var brewInstalled: Bool
    public var brewPath: String?
    public var javaInstalled: Bool
    public var javaHome: String?
    public var javaVersion: String?
    public var sdkRootInstalled: Bool
    public var sdkRootPath: String?
    public var avdmanagerInstalled: Bool
    public var sdkmanagerInstalled: Bool
    public var adbInstalled: Bool
    public var emulatorInstalled: Bool

    public var allInstalled: Bool {
        brewInstalled && javaInstalled && sdkRootInstalled
            && avdmanagerInstalled && sdkmanagerInstalled
            && adbInstalled && emulatorInstalled
    }

    public var missingCount: Int {
        [brewInstalled, javaInstalled, sdkRootInstalled,
         avdmanagerInstalled, sdkmanagerInstalled,
         adbInstalled, emulatorInstalled]
            .filter { !$0 }.count
    }

    public init() {
        self.brewInstalled = false
        self.brewPath = nil
        self.javaInstalled = false
        self.javaHome = nil
        self.javaVersion = nil
        self.sdkRootInstalled = false
        self.sdkRootPath = nil
        self.avdmanagerInstalled = false
        self.sdkmanagerInstalled = false
        self.adbInstalled = false
        self.emulatorInstalled = false
    }
}

// MARK: - AndroidSDK

@MainActor
public final class AndroidSDK: ObservableObject {
    public static let shared = AndroidSDK()

    @Published public private(set) var setupProgress: SetupProgress = .init(phase: .idle, message: "")
    @Published public private(set) var sdkRoot: URL?
    @Published public private(set) var isInstalling = false
    @Published public private(set) var installPhase: SetupProgress.Phase = .idle
    @Published public private(set) var installMessage: String = ""
    @Published public private(set) var installPercent: Double = 0

    public var sdkRootPath: String? { sdkRoot?.path }
    public var avdmanagerPath: String? {
        sdkRoot?.appendingPathComponent("cmdline-tools/latest/bin/avdmanager").path
    }
    public var sdkmanagerPath: String? {
        sdkRoot?.appendingPathComponent("cmdline-tools/latest/bin/sdkmanager").path
    }
    public var emulatorPath: String? {
        sdkRoot?.appendingPathComponent("emulator/emulator").path
    }
    public var adbPath: String? {
        sdkRoot?.appendingPathComponent("platform-tools/adb").path
    }

    private init() {}

    // MARK: - Dependency Checking

    public func checkDependencies() -> DependencyStatus {
        var status = DependencyStatus()

        // Homebrew
        let brewPath = "/opt/homebrew/bin/brew"
        status.brewInstalled = FileManager.default.isExecutableFile(atPath: brewPath)
        status.brewPath = status.brewInstalled ? brewPath : nil

        // Java
        if let javaHome = Self.detectJavaHome() {
            status.javaInstalled = true
            status.javaHome = javaHome
            status.javaVersion = Self.javaVersion(at: javaHome)
        }

        // SDK Root
        if let root = detectSDKRoot() {
            status.sdkRootInstalled = true
            status.sdkRootPath = root.path
        } else {
            status.sdkRootPath = nil
        }

        // Individual tools
        let rootPath = status.sdkRootPath ?? "/opt/homebrew/share/android-commandlinetools"
        status.avdmanagerInstalled = FileManager.default.isExecutableFile(
            atPath: "\(rootPath)/cmdline-tools/latest/bin/avdmanager")
        status.sdkmanagerInstalled = FileManager.default.isExecutableFile(
            atPath: "\(rootPath)/cmdline-tools/latest/bin/sdkmanager")
        status.adbInstalled = FileManager.default.isExecutableFile(
            atPath: "\(rootPath)/platform-tools/adb")
        status.emulatorInstalled = FileManager.default.isExecutableFile(
            atPath: "\(rootPath)/emulator/emulator")

        return status
    }

    // MARK: - One-Click Install

    public func installAllMissing() async throws {
        isInstalling = true
        installPercent = 0
        defer { isInstalling = false }

        let status = checkDependencies()

        // Nothing to install
        if status.allInstalled {
            installPhase = .completed
            installMessage = "All dependencies are ready."
            installPercent = 1.0
            return
        }

        let totalSteps: Double = 3  // SDK + Java + platform-tools/emulator
        var completedSteps: Double = 0

        // Step 1: Install Android command line tools if missing
        if !status.sdkRootInstalled {
            installPhase = .installingCommandLineTools
            installMessage = "Installing Android command line tools..."
            installPercent = completedSteps / totalSteps
            try await installCommandLineTools()
            completedSteps += 1
        }

        // Step 2: Install Java if missing
        if !status.javaInstalled {
            installPhase = .installingJDK
            installMessage = "Installing OpenJDK..."
            installPercent = completedSteps / totalSteps
            try await installJava()
            completedSteps += 1
        }

        // Step 3: Install platform-tools + emulator if missing
        if !status.adbInstalled || !status.emulatorInstalled {
            installPhase = .installingPlatformTools
            installMessage = "Installing platform-tools & emulator..."
            installPercent = completedSteps / totalSteps
            if let root = detectSDKRoot() ?? URL(string: "file:///opt/homebrew/share/android-commandlinetools") {
                try await installSDKComponents(at: root)
            }
            completedSteps += 1
        }

        // Re-detect SDK root
        if let root = detectSDKRoot() {
            sdkRoot = root
        }

        installPhase = .completed
        installMessage = "All dependencies installed successfully!"
        installPercent = 1.0
    }

    // MARK: - Helpers

    private func installCommandLineTools() async throws {
        let brew = "/opt/homebrew/bin/brew"
        if !FileManager.default.isExecutableFile(atPath: brew) {
            throw AVDManagerError.missingSDK
        }
        _ = try await ProcessRunner.runWithCancellation(
            brew,
            arguments: ["install", "--cask", "android-commandlinetools"]
        )
    }

    private func installJava() async throws {
        let brew = "/opt/homebrew/bin/brew"
        if !FileManager.default.isExecutableFile(atPath: brew) {
            throw AVDManagerError.missingSDK
        }
        _ = try await ProcessRunner.runWithCancellation(
            brew,
            arguments: ["install", "openjdk"]
        )
    }

    private static func javaVersion(at javaHome: String) -> String? {
        let javaBin = "\(javaHome)/bin/java"
        guard FileManager.default.isExecutableFile(atPath: javaBin) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaBin)
        process.arguments = ["-version"]
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
            let output = String(data: data, encoding: .utf8) ?? ""
            // Extract version line e.g. "openjdk version \"26.0.1\" 2026-04-21"
            return output.components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespaces) ?? output.trimmingCharacters(in: .whitespaces)
        } catch {
            return nil
        }
    }

    public func setupIfNeeded() async {
        setupProgress = .init(phase: .detecting, message: "Detecting Android SDK...", percent: 0.1)

        if let root = detectSDKRoot(), validateTools(at: root) {
            sdkRoot = root
            setupProgress = .init(phase: .completed, message: "Android SDK ready at \(root.path)", percent: 1.0)
            return
        }

        do {
            try await installMissingDependencies()
            guard let root = detectSDKRoot() else {
                setupProgress = .init(
                    phase: .failed,
                    message: "SDK installation failed: could not locate SDK after installation.",
                    percent: 1.0
                )
                return
            }
            sdkRoot = root
            try await installSDKComponents(at: root)
            setupProgress = .init(phase: .completed, message: "Android SDK ready at \(root.path)", percent: 1.0)
        } catch {
            setupProgress = .init(
                phase: .failed,
                message: "Setup failed: \(error.localizedDescription)",
                percent: 1.0
            )
        }
    }

    public func environmentForSubprocess() -> [String: String] {
        var env = ProcessInfo.processInfo.environment

        let rootPath: String
        if let root = sdkRoot {
            rootPath = root.path
        } else if let envRoot = env["ANDROID_HOME"] ?? env["ANDROID_SDK_ROOT"] {
            rootPath = envRoot
        } else {
            rootPath = "/opt/homebrew/share/android-commandlinetools"
        }

        env["ANDROID_HOME"] = rootPath
        env["ANDROID_SDK_ROOT"] = rootPath

        let jdkPath = env["JAVA_HOME"] ?? Self.detectJavaHome() ?? "/opt/homebrew/opt/openjdk"
        env["JAVA_HOME"] = jdkPath

        let sdkPaths = [
            "\(rootPath)/cmdline-tools/latest/bin",
            "\(rootPath)/emulator",
            "\(rootPath)/platform-tools",
            "\(jdkPath)/bin",
            "/opt/homebrew/bin"
        ]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = (sdkPaths + [existingPath]).joined(separator: ":")

        return env
    }
}

private extension AndroidSDK {
    func detectSDKRoot() -> URL? {
        let env = ProcessInfo.processInfo.environment
        if let androidHome = env["ANDROID_HOME"] ?? env["ANDROID_SDK_ROOT"],
           FileManager.default.fileExists(atPath: androidHome) {
            return URL(fileURLWithPath: androidHome)
        }

        let candidates = [
            "/opt/homebrew/share/android-commandlinetools",
            "/opt/homebrew/share/android-sdk",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Android/sdk").path,
            "/usr/local/share/android-commandlinetools"
        ]

        return candidates
            .compactMap { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func validateTools(at root: URL) -> Bool {
        let required = [
            "cmdline-tools/latest/bin/sdkmanager",
            "cmdline-tools/latest/bin/avdmanager",
            "emulator/emulator",
            "platform-tools/adb"
        ]
        guard required.allSatisfy({
            FileManager.default.isExecutableFile(atPath: root.appendingPathComponent($0).path)
        }) else { return false }

        // Also require a working Java runtime
        guard Self.detectJavaHome() != nil else { return false }

        return true
    }

    static func detectJavaHome() -> String? {
        // 1. Check JAVA_HOME env
        if let javaHome = ProcessInfo.processInfo.environment["JAVA_HOME"],
           FileManager.default.isExecutableFile(atPath: "\(javaHome)/bin/java") {
            return javaHome
        }

        // 2. Try /usr/libexec/java_home
        let javaHomeProc = Process()
        javaHomeProc.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        javaHomeProc.arguments = []
        let outPipe = Pipe()
        javaHomeProc.standardOutput = outPipe
        javaHomeProc.standardError = Pipe()
        do {
            try javaHomeProc.run()
            javaHomeProc.waitUntilExit()
            let data = try outPipe.fileHandleForReading.readToEnd() ?? Data()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !path.isEmpty, FileManager.default.isExecutableFile(atPath: "\(path)/bin/java") {
                return path
            }
        } catch {}

        // 3. Check common Homebrew JDK paths (newest first)
        let candidates = [
            "/opt/homebrew/opt/openjdk",
            "/opt/homebrew/opt/openjdk@26",
            "/opt/homebrew/opt/openjdk@25",
            "/opt/homebrew/opt/openjdk@21",
            "/opt/homebrew/opt/openjdk@17",
            "/opt/homebrew/opt/openjdk@11",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: "\(path)/bin/java") {
                return path
            }
        }

        return nil
    }

    func installMissingDependencies() async throws {
        let brew = "/opt/homebrew/bin/brew"

        let sdkmanagerPath = "/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager"
        if !FileManager.default.isExecutableFile(atPath: sdkmanagerPath) {
            setupProgress = .init(
                phase: .installingCommandLineTools,
                message: "Installing Android command line tools via Homebrew...",
                percent: 0.2
            )
            _ = try await ProcessRunner.runWithCancellation(
                brew,
                arguments: ["install", "--cask", "android-commandlinetools"]
            )
        }

        let adbPath = "/opt/homebrew/share/android-platform-tools/platform-tools/adb"
        if !FileManager.default.isExecutableFile(atPath: adbPath) {
            setupProgress = .init(
                phase: .installingPlatformTools,
                message: "Installing Android platform tools via Homebrew...",
                percent: 0.4
            )
            _ = try await ProcessRunner.runWithCancellation(
                brew,
                arguments: ["install", "--cask", "android-platform-tools"]
            )
        }

        // Install Java if none found
        if Self.detectJavaHome() == nil {
            setupProgress = .init(
                phase: .installingJDK,
                message: "Installing OpenJDK via Homebrew...",
                percent: 0.6
            )
            _ = try await ProcessRunner.runWithCancellation(
                brew,
                arguments: ["install", "openjdk"]
            )
        }
    }

    func installSDKComponents(at root: URL) async throws {
        let env = environmentForSubprocess()
        let sdkmanager = root.appendingPathComponent("cmdline-tools/latest/bin/sdkmanager").path

        setupProgress = .init(
            phase: .installingPlatformTools,
            message: "Installing platform-tools via sdkmanager...",
            percent: 0.75
        )
        let platformToolsResult = try await ProcessRunner.runWithCancellation(
            sdkmanager,
            arguments: ["--install", "platform-tools"],
            environment: env
        )
        guard platformToolsResult.exitCode == 0 else {
            throw AVDManagerError.subprocessFailed(
                exitCode: platformToolsResult.exitCode,
                stderr: platformToolsResult.stderr
            )
        }

        setupProgress = .init(
            phase: .installingEmulator,
            message: "Installing emulator via sdkmanager...",
            percent: 0.9
        )
        let emulatorResult = try await ProcessRunner.runWithCancellation(
            sdkmanager,
            arguments: ["--install", "emulator"],
            environment: env
        )
        guard emulatorResult.exitCode == 0 else {
            throw AVDManagerError.subprocessFailed(
                exitCode: emulatorResult.exitCode,
                stderr: emulatorResult.stderr
            )
        }
    }
}
