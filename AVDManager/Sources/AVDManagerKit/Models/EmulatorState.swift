import Foundation

public enum EmulatorState: String, Codable, Sendable, CaseIterable, Identifiable {
    public var id: String { rawValue }
    case stopped
    case booting
    case running
    case stopping
    case error

    public var localizedName: String {
        switch self {
        case .stopped:
            return NSLocalizedString("state_stopped", comment: "Emulator state: stopped")
        case .booting:
            return NSLocalizedString("state_booting", comment: "Emulator state: booting")
        case .running:
            return NSLocalizedString("state_running", comment: "Emulator state: running")
        case .stopping:
            return NSLocalizedString("state_stopping", comment: "Emulator state: stopping")
        case .error:
            return NSLocalizedString("state_error", comment: "Emulator state: error")
        }
    }

    public var systemImage: String {
        switch self {
        case .stopped:
            return "stop.circle"
        case .booting:
            return "arrow.clockwise.circle"
        case .running:
            return "play.circle.fill"
        case .stopping:
            return "arrow.clockwise.circle"
        case .error:
            return "exclamationmark.triangle"
        }
    }
}
