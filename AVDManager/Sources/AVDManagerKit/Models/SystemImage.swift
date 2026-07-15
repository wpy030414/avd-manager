import Foundation

public struct SystemImage: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var package: String { id }
    public var description: String
    public var apiLevel: Int
    public var variant: String
    public var abi: String
    public var isInstalled: Bool
    public var sizeInfo: String?
    public var downloadProgress: Double?
    public var installProgress: Double?

    public init(
        id: String,
        apiLevel: Int,
        variant: String,
        abi: String,
        isInstalled: Bool = false,
        sizeInfo: String? = nil,
        description: String? = nil,
        downloadProgress: Double? = nil
    ) {
        self.id = id
        self.apiLevel = apiLevel
        self.variant = variant
        self.abi = abi
        self.isInstalled = isInstalled
        self.sizeInfo = sizeInfo
        self.description = description ?? ""
        self.downloadProgress = downloadProgress
        self.installProgress = nil
    }

    public init?(packagePath: String) {
        let parts = packagePath.components(separatedBy: ";")
        guard parts.count >= 4,
              parts[0] == "system-images",
              let api = Int(parts[1].replacingOccurrences(of: "android-", with: "")) else {
            return nil
        }

        self.id = packagePath
        self.apiLevel = api
        self.variant = parts[2]
        self.abi = parts[3]
        self.isInstalled = false
        self.sizeInfo = nil
        self.description = ""
        self.downloadProgress = nil
    }

    public var localizedDescription: String {
        "Android \(androidVersion) (API \(apiLevel)) — \(variantLabel), \(abiLabel)"
    }

    /// Human-readable variant name.
    public var variantLabel: String {
        switch variant {
        case let v where v.hasPrefix("google_apis_playstore"): return "Google Play"
        case let v where v.hasPrefix("google_apis"): return "Google APIs"
        case let v where v.hasPrefix("google_atd"): return "Google ATD"
        case let v where v.hasPrefix("aosp_atd"): return "AOSP ATD"
        case let v where v.hasPrefix("default"): return "AOSP"
        case let v where v.hasPrefix("android-tv"): return "Android TV"
        case let v where v.hasPrefix("android-wear"): return "Wear OS"
        case let v where v.hasPrefix("android-desktop"): return "Desktop"
        case let v where v.hasPrefix("android-automotive"): return "Automotive"
        case let v where v.hasPrefix("android-xr"): return "XR"
        default: return variant.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    /// Human-readable ABI name.
    public var abiLabel: String {
        switch abi {
        case "arm64-v8a": return "ARM 64"
        case "armeabi-v7a": return "ARM v7"
        case "x86_64": return "x86 64"
        case "x86": return "x86"
        default: return abi
        }
    }

    /// Human-readable Android version name for the API level.
    public var androidVersion: String {
        switch apiLevel {
        case 37: return "17"
        case 36: return "16"
        case 35: return "15"
        case 34: return "14"
        case 33: return "13"
        case 32: return "12L"
        case 31: return "12"
        case 30: return "11"
        case 29: return "10"
        case 28: return "9 Pie"
        case 27: return "8.1 Oreo"
        case 26: return "8.0 Oreo"
        case 25: return "7.1 Nougat"
        case 24: return "7.0 Nougat"
        case 23: return "6.0 Marshmallow"
        case 22: return "5.1 Lollipop"
        case 21: return "5.0 Lollipop"
        case 20: return "4.4W KitKat Wear"
        case 19: return "4.4 KitKat"
        case 18: return "4.3 Jelly Bean"
        case 17: return "4.2 Jelly Bean"
        case 16: return "4.1 Jelly Bean"
        case 15: return "4.0.3 Ice Cream Sandwich"
        case 14: return "4.0 Ice Cream Sandwich"
        case 13: return "3.2 Honeycomb"
        case 12: return "3.1 Honeycomb"
        case 11: return "3.0 Honeycomb"
        case 10: return "2.3.3 Gingerbread"
        case 9: return "2.3 Gingerbread"
        case 8: return "2.2 Froyo"
        case 7: return "2.1 Eclair"
        case 5...6: return "2.0 Eclair"
        case 4: return "1.6 Donut"
        case 3: return "1.5 Cupcake"
        default: return "API \(apiLevel)"
        }
    }
}
