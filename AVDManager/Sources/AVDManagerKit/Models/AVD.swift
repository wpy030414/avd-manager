import Foundation

public struct AVD: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var device: String
    public var package: String
    public var apiLevel: Int
    public var abi: String?
    public var skin: String?
    public var path: String?
    public var basedOn: String?       // Android version string, e.g. "Android 16.0"
    public var directorySize: UInt64?
    public var lastBootTime: Date?
    public var state: EmulatorState
    public var consolePort: Int?

    /// Backward-compatible alias used by existing UI views (`deviceName`).
    public var deviceName: String? { device.isEmpty ? nil : device }
    /// Backward-compatible alias used by existing UI views (`target`).
    /// Prefer `basedOn` for display; falls back to package path.
    public var target: String? {
        if let b = basedOn, !b.isEmpty { return b }
        return package.isEmpty ? nil : package
    }
    /// Backward-compatible alias used by existing UI views (`assignedPort`).
    public var assignedPort: Int? { consolePort }

    public init(
        id: UUID = UUID(),
        name: String,
        device: String,
        package: String,
        apiLevel: Int,
        abi: String? = nil,
        skin: String? = nil,
        path: String? = nil,
        basedOn: String? = nil,
        directorySize: UInt64? = nil,
        lastBootTime: Date? = nil,
        state: EmulatorState = .stopped,
        consolePort: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.device = device
        self.package = package
        self.apiLevel = apiLevel
        self.abi = abi
        self.skin = skin
        self.path = path
        self.basedOn = basedOn
        self.directorySize = directorySize
        self.lastBootTime = lastBootTime
        self.state = state
        self.consolePort = consolePort
    }

    /// Convenience initializer matching existing view call sites that pass
    /// `deviceName`, `target`, and `assignedPort`.
    public init(
        id: UUID = UUID(),
        name: String,
        deviceName: String? = nil,
        target: String? = nil,
        apiLevel: Int? = nil,
        abi: String? = nil,
        skin: String? = nil,
        path: String? = nil,
        basedOn: String? = nil,
        directorySize: UInt64? = nil,
        lastBootTime: Date? = nil,
        assignedPort: Int? = nil,
        state: EmulatorState = .stopped
    ) {
        self.id = id
        self.name = name
        self.device = deviceName ?? ""
        self.package = target ?? ""
        self.apiLevel = apiLevel ?? 0
        self.abi = abi
        self.skin = skin
        self.path = path
        self.basedOn = basedOn
        self.directorySize = directorySize
        self.lastBootTime = lastBootTime
        self.consolePort = assignedPort
        self.state = state
    }
}
