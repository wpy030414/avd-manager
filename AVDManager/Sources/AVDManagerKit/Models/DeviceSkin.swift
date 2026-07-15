import Foundation

public struct DeviceSkin: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let device: String
    public let oem: String

    public init(id: String, name: String, device: String, oem: String) {
        self.id = id
        self.name = name
        self.device = device
        self.oem = oem
    }
}
