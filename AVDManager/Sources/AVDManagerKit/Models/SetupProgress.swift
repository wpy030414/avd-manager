import Foundation

public struct SetupProgress: Sendable {
    public let phase: Phase
    public let message: String
    public let percent: Double?

    public init(phase: Phase, message: String, percent: Double? = nil) {
        self.phase = phase
        self.message = message
        self.percent = percent
    }

    public enum Phase: Sendable {
        case idle
        case detecting
        case installingHomebrew
        case installingJDK
        case installingCommandLineTools
        case installingPlatformTools
        case installingEmulator
        case completed
        case failed
    }
}
