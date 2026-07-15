import Foundation

public struct DownloadProgress: Sendable {
    public let package: String
    public let percent: Double
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let isComplete: Bool
    public let errorMessage: String?

    public let phase: Phase

    public enum Phase: String, Sendable {
        case downloading = "downloading"
        case installing = "installing"
        case complete = "complete"
    }

    public init(
        package: String,
        percent: Double,
        bytesDownloaded: Int64,
        totalBytes: Int64,
        isComplete: Bool,
        errorMessage: String?,
        phase: Phase = .downloading
    ) {
        self.package = package
        self.percent = percent
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.isComplete = isComplete
        self.errorMessage = errorMessage
        self.phase = phase
    }
}
