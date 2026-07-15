import Foundation

public enum OutputParsing {
    public static func extractAVDName(from output: String) -> String? {
        output.lines()
            .first { $0.contains("Name:") }
            .flatMap { line in
                line.components(separatedBy: "Name:")
                    .dropFirst()
                    .first?
                    .trimmingCharacters(in: .whitespaces)
            }
    }

    public static func parseAVDList(_ output: String) -> [AVD] {
        let lines = output.lines()
        var avds: [AVD] = []
        var currentName: String?
        var currentDevice: String?
        var currentPath: String?
        var currentTarget: String?
        var currentAPI: Int?
        var currentABI: String?
        var currentBasedOn: String?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            guard !line.hasPrefix("Available") && !line.hasPrefix("---") else { continue }

            // Start of a new AVD entry
            if line.hasPrefix("Name:") {
                // Commit the previous AVD if any
                if let name = currentName {
                    avds.append(AVD(
                        name: name,
                        device: currentDevice ?? "",
                        package: currentTarget ?? "",
                        apiLevel: currentAPI ?? 0,
                        abi: currentABI,
                        path: currentPath,
                        basedOn: currentBasedOn
                    ))
                }
                currentName = line.replacingOccurrences(of: "Name:", with: "").trimmingCharacters(in: .whitespaces)
                currentDevice = nil
                currentPath = nil
                currentTarget = nil
                currentAPI = nil
                currentABI = nil
                currentBasedOn = nil
                continue
            }

            guard currentName != nil else { continue }

            if line.hasPrefix("Device:") {
                currentDevice = line.replacingOccurrences(of: "Device:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Path:") {
                currentPath = line.replacingOccurrences(of: "Path:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Target:") {
                currentTarget = line.replacingOccurrences(of: "Target:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Based on:") {
                // "Based on: Android 7.1.1 ("Nougat") Tag/ABI: google_apis/arm64-v8a"
                let based = line.replacingOccurrences(of: "Based on:", with: "").trimmingCharacters(in: .whitespaces)
                // Extract API level from "Android X.Y.Z"
                if let androidRange = based.range(of: "Android ") {
                    let afterAndroid = based[androidRange.upperBound...]
                    let versionStr = afterAndroid.components(separatedBy: " ").first ?? ""
                    // Store the clean Android version string for display
                    currentBasedOn = "Android \(versionStr)"
                    // Parse major version
                    let majorStr = versionStr.components(separatedBy: ".").first ?? versionStr
                    currentAPI = Int(majorStr)
                    // Convert Android version to API level
                    if let api = currentAPI {
                        currentAPI = apiLevelFromAndroidVersion(api)
                    }
                }
                // Extract ABI from "Tag/ABI: google_apis/arm64-v8a"
                if let tagRange = based.range(of: "Tag/ABI:") {
                    let afterTag = based[tagRange.upperBound...].trimmingCharacters(in: .whitespaces)
                    let parts = afterTag.components(separatedBy: "/")
                    if parts.count >= 2 {
                        currentABI = parts.last
                    }
                }
            }
        }

        // Commit the last AVD
        if let name = currentName {
            avds.append(AVD(
                name: name,
                device: currentDevice ?? "",
                package: currentTarget ?? "",
                apiLevel: currentAPI ?? 0,
                abi: currentABI,
                path: currentPath,
                basedOn: currentBasedOn
            ))
        }

        return avds
    }

    /// Convert Android marketing version to API level.
    private static func apiLevelFromAndroidVersion(_ major: Int) -> Int {
        switch major {
        case 17: return 37
        case 16: return 36
        case 15: return 35
        case 14: return 34
        case 13: return 33
        case 12: return 32  // also 31 for 12
        case 11: return 30
        case 10: return 29
        case 9: return 28
        case 8: return 27  // 8.1 → 27, 8.0 → 26 (approximate)
        case 7: return 25  // 7.1 → 25
        case 6: return 23
        case 5: return 22  // 5.1 → 22, 5.0 → 21
        case 4: return 19
        default: return major
        }
    }

    public static func parseSystemImages(_ output: String) -> [SystemImage] {
        let lines = output.lines()
        var images: [SystemImage] = []
        var installedPackageIDs = Set<String>()
        var inAvailableSection = false
        var inInstalledSection = false

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Detect section headers (case-insensitive)
            let lower = line.lowercased()
            if lower.hasPrefix("installed packages") {
                inInstalledSection = true
                inAvailableSection = false
                continue
            }
            if lower.hasPrefix("available packages") || lower.hasPrefix("available updates") {
                inAvailableSection = true
                inInstalledSection = false
                continue
            }

            // Stop parsing on the next unrelated section header
            if !inAvailableSection && !inInstalledSection { continue }
            if (lower.hasPrefix("available") && !lower.hasPrefix("available packages") && !lower.hasPrefix("available updates"))
                || lower.hasPrefix("installed") && !lower.hasPrefix("installed packages") {
                inAvailableSection = false
                inInstalledSection = false
                continue
            }

            // Skip table headers / separators
            if line.hasPrefix("Path") || line.hasPrefix("-------") {
                continue
            }

            // Parse system-images lines
            guard line.hasPrefix("system-images;") else { continue }

            let components = line.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let packagePath = components.first ?? line

            guard var image = SystemImage(packagePath: packagePath) else { continue }

            // Column 2: version/revision, Column 3: description, Column 4 (installed only): location
            let version = components.count > 1 ? components[1] : ""
            let description = components.count > 2 ? components[2] : ""
            if !description.isEmpty {
                image.description = description
            }
            // Parse revision from version string
            if let rev = Int(version) {
                image.sizeInfo = "rev. \(rev)"
            }

            // Mark installed
            if inInstalledSection {
                image.isInstalled = true
                installedPackageIDs.insert(packagePath)
            }

            images.append(image)
        }

        // Deduplicate: prefer the installed version when an image appears in both sections.
        var seen: [String: SystemImage] = [:]
        for image in images {
            let key = image.id
            if let existing = seen[key] {
                // Keep installed version, or merge install flag
                var merged = existing
                merged.isInstalled = existing.isInstalled || image.isInstalled
                seen[key] = merged
            } else {
                seen[key] = image
            }
        }
        return Array(seen.values)
    }

    public static func parseDeviceList(_ output: String) -> [DeviceSkin] {
        let lines = output.lines()
        var devices: [DeviceSkin] = []

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // `adb devices -l` output, e.g.:
            // emulator-5554 device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emulator64_arm64 transport_id:1
            if line.hasPrefix("emulator-") || line.hasPrefix("localhost:") || line.hasPrefix("usb:") {
                let parts = line.split(separator: " ").map(String.init)
                guard let serial = parts.first else { continue }
                let model = value(forKey: "model", in: line)
                let deviceName = value(forKey: "device", in: line) ?? serial
                let product = value(forKey: "product", in: line) ?? ""
                devices.append(DeviceSkin(
                    id: serial,
                    name: model ?? deviceName,
                    device: deviceName,
                    oem: product
                ))
            } else if !line.hasPrefix("-")
                        && !line.hasPrefix("Available")
                        && !line.hasPrefix("List")
                        && !line.hasPrefix("P ")
                        && !line.hasPrefix("id")
                        && !line.hasPrefix("0 ") {
                // `avdmanager list device -c` compact output.
                devices.append(DeviceSkin(id: line, name: line, device: line, oem: ""))
            }
        }

        return devices
    }

    public static func parseDownloadProgress(from line: String, package: String) -> DownloadProgress? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()

        // Detect the phase from the line content
        let phase: DownloadProgress.Phase
        if lower.contains("unzipping") || lower.contains("installing") {
            phase = .installing
        } else {
            phase = .downloading
        }

        if let percent = extractPercent(from: trimmed),
           let (downloaded, total) = extractByteProgress(from: trimmed) {
            return DownloadProgress(
                package: package,
                percent: percent,
                bytesDownloaded: downloaded,
                totalBytes: total,
                isComplete: percent >= 1.0,
                errorMessage: nil,
                phase: phase
            )
        }

        // Simple percentage-only lines (e.g. from loading bar)
        if let percent = extractPercent(from: trimmed) {
            return DownloadProgress(
                package: package,
                percent: percent,
                bytesDownloaded: 0,
                totalBytes: 0,
                isComplete: percent >= 1.0,
                errorMessage: nil,
                phase: phase
            )
        }

        if lower.contains("done")
            || lower.contains("installed")
            || lower.contains("complete") {
            return DownloadProgress(
                package: package,
                percent: 1.0,
                bytesDownloaded: 1,
                totalBytes: 1,
                isComplete: true,
                errorMessage: nil,
                phase: .complete
            )
        }

        return nil
    }

    public static func apiLevel(fromPackage package: String) -> Int {
        let pattern = #"android-(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: package, range: NSRange(package.startIndex..., in: package)),
              let range = Range(match.range(at: 1), in: package),
              let level = Int(package[range]) else { return 0 }
        return level
    }

    public static func abi(fromPackage package: String) -> String {
        let known = ["arm64-v8a", "armeabi-v7a", "x86_64", "x86"]
        return known.first { package.contains($0) } ?? "unknown"
    }
}

private extension OutputParsing {
    static func extractPercent(from line: String) -> Double? {
        let pattern = #"(\d+)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line),
              let value = Double(line[range]) else { return nil }
        return value / 100.0
    }

    static func extractByteProgress(from line: String) -> (downloaded: Int64, total: Int64)? {
        let pattern = #"([\d.]+)\s*([KMGT]?B)\s*/\s*([\d.]+)\s*([KMGT]?B)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }

        let downloaded = parseBytes(
            String(line[Range(match.range(at: 1), in: line)!]),
            unit: String(line[Range(match.range(at: 2), in: line)!])
        )
        let total = parseBytes(
            String(line[Range(match.range(at: 3), in: line)!]),
            unit: String(line[Range(match.range(at: 4), in: line)!])
        )
        return (downloaded, total)
    }

    static func parseBytes(_ value: String, unit: String) -> Int64 {
        guard let number = Double(value) else { return 0 }
        let multiplier: Double
        switch unit.uppercased() {
        case "B": multiplier = 1
        case "KB": multiplier = 1_024
        case "MB": multiplier = 1_024 * 1_024
        case "GB": multiplier = 1_024 * 1_024 * 1_024
        case "TB": multiplier = 1_024 * 1_024 * 1_024 * 1_024
        default: multiplier = 1
        }
        return Int64(number * multiplier)
    }

    static func value(forKey key: String, in line: String) -> String? {
        let pattern = #"\b\#(key):([^\s]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range])
    }
}

private extension String {
    func lines() -> [String] {
        components(separatedBy: .newlines)
    }
}
