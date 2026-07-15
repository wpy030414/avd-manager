import Foundation

public enum AVDManagerError: Error, Sendable {
    case setupFailed(String)
    case executableNotFound(String)
    case invalidOutput(String)
    case subprocessFailed(exitCode: Int32, stderr: String)
    case cancellationFailed
    case avdNotFound(String)
    case emulatorNotRunning
    case adbDeviceNotFound(Int)
    case installationFailed(String)
    case windowControlFailed(String)
    case missingSDK
    case unsupportedOS
}
