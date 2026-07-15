import Foundation

public actor AVDService {
    private let sdk: AndroidSDK

    public init(sdk: AndroidSDK) {
        self.sdk = sdk
    }

    public func listAVDs() async throws -> [AVD] {
        guard let avdmanager = await sdk.avdmanagerPath else {
            throw AVDManagerError.missingSDK
        }
        let env = await sdk.environmentForSubprocess()
        let result = try await ProcessRunner.run(
            avdmanager,
            arguments: ["list", "avd"],
            environment: env
        )
        guard result.exitCode == 0 else {
            throw AVDManagerError.subprocessFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        var avds = OutputParsing.parseAVDList(result.stdout)
        // Enrich with filesystem info
        avds = avds.map { avd in
            var enriched = avd
            if let path = avd.path {
                let expanded = NSString(string: path).expandingTildeInPath
                let url = URL(fileURLWithPath: expanded)
                enriched.directorySize = Self.directorySize(of: url)
                enriched.lastBootTime = Self.lastBootTime(of: url)
            }
            return enriched
        }
        return avds
    }

    private static func directorySize(of url: URL) -> UInt64? {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let size = values.fileSize else { continue }
            total += UInt64(size)
        }
        return total > 0 ? total : nil
    }

    private static func lastBootTime(of url: URL) -> Date? {
        let hardwareIni = url.appendingPathComponent("hardware-qemu.ini")
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: hardwareIni.path) else {
            // Fallback: use AVD directory modification date
            return (try? FileManager.default.attributesOfItem(atPath: url.path))
                .flatMap { $0[.modificationDate] as? Date }
        }
        return attrs[.modificationDate] as? Date
    }

    public func createAVD(name: String, package: String, device: String) async throws -> AVD {
        guard let avdmanager = await sdk.avdmanagerPath else {
            throw AVDManagerError.missingSDK
        }
        let env = await sdk.environmentForSubprocess()
        let result = try await ProcessRunner.run(
            avdmanager,
            arguments: ["create", "avd", "-n", name, "-k", package, "-d", device, "-f"],
            environment: env,
            input: Data("\n".utf8)
        )
        guard result.exitCode == 0 else {
            throw AVDManagerError.subprocessFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return AVD(
            name: name,
            device: device,
            package: package,
            apiLevel: OutputParsing.apiLevel(fromPackage: package)
        )
    }

    public func deleteAVD(name: String) async throws {
        guard let avdmanager = await sdk.avdmanagerPath else {
            throw AVDManagerError.missingSDK
        }
        let env = await sdk.environmentForSubprocess()
        let result = try await ProcessRunner.run(
            avdmanager,
            arguments: ["delete", "avd", "-n", name],
            environment: env
        )
        guard result.exitCode == 0 else {
            throw AVDManagerError.subprocessFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
    }

    /// Rename an AVD by moving its .avd directory and .ini file, then updating the ini contents.
    public func renameAVD(from oldName: String, to newName: String) async throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let avdBase = home.appendingPathComponent(".android/avd")
        let oldDir = avdBase.appendingPathComponent("\(oldName).avd")
        let newDir = avdBase.appendingPathComponent("\(newName).avd")
        let oldIni = avdBase.appendingPathComponent("\(oldName).ini")
        let newIni = avdBase.appendingPathComponent("\(newName).ini")

        let fm = FileManager.default
        guard fm.fileExists(atPath: oldDir.path) else {
            throw AVDManagerError.subprocessFailed(exitCode: -1, stderr: "AVD directory not found: \(oldDir.path)")
        }
        guard fm.fileExists(atPath: oldIni.path) else {
            throw AVDManagerError.subprocessFailed(exitCode: -1, stderr: "AVD ini not found: \(oldIni.path)")
        }
        guard !fm.fileExists(atPath: newDir.path) else {
            throw AVDManagerError.subprocessFailed(exitCode: -1, stderr: "Target AVD '\(newName)' already exists")
        }

        // Move directory and ini
        try fm.moveItem(at: oldDir, to: newDir)
        try fm.moveItem(at: oldIni, to: newIni)

        // Update ini path reference
        let iniContent = try String(contentsOf: newIni, encoding: .utf8)
        let updatedIni = iniContent.replacingOccurrences(of: "path=\(oldDir.path)", with: "path=\(newDir.path)")
            .replacingOccurrences(of: "path=\(oldName).avd", with: "path=\(newName).avd")
        try updatedIni.write(to: newIni, atomically: true, encoding: .utf8)

        // Update config.ini inside the AVD directory if it exists
        let configIni = newDir.appendingPathComponent("config.ini")
        if fm.fileExists(atPath: configIni.path) {
            let config = try String(contentsOf: configIni, encoding: .utf8)
            let updatedConfig = config
                .replacingOccurrences(of: "AvdId=\(oldName)", with: "AvdId=\(newName)")
                .replacingOccurrences(of: "avd.ini.displayname=\(oldName)", with: "avd.ini.displayname=\(newName)")
            try updatedConfig.write(to: configIni, atomically: true, encoding: .utf8)
        }
    }

    public func listDevices() async throws -> [DeviceSkin] {
        guard let avdmanager = await sdk.avdmanagerPath else {
            throw AVDManagerError.missingSDK
        }
        let env = await sdk.environmentForSubprocess()
        let result = try await ProcessRunner.run(
            avdmanager,
            arguments: ["list", "device", "-c"],
            environment: env
        )
        guard result.exitCode == 0 else {
            throw AVDManagerError.subprocessFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }
        return OutputParsing.parseDeviceList(result.stdout)
    }
}
