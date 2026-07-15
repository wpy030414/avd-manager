import Foundation
import AppKit

@MainActor
public final class WindowController {
    @available(macOS, deprecated: 14.0, message: "Uses the legacy activateIgnoringOtherApps option as required by the caller.")
    public static func bringToFront(pid: pid_t) {
        NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
    }

    public static func minimize(pid: pid_t) async throws {
        try await runAppleScript(pid: pid, action: "minimize")
    }

    public static func close(pid: pid_t) async throws {
        do {
            try await runAppleScript(pid: pid, action: "close")
        } catch {
            // Accessibility/AppleScript failed; fall back to terminating the process.
            kill(pid, SIGTERM)
        }
    }

    private static func runAppleScript(pid: pid_t, action: String) async throws {
        let script = """
        tell application "System Events"
            set qemuProcs to every process whose unix id is \(pid)
            repeat with p in qemuProcs
                \(action) p
            end repeat
        end tell
        """
        let result = try await ProcessRunner.run(
            "/usr/bin/osascript",
            arguments: ["-e", script]
        )
        guard result.exitCode == 0 else {
            throw AVDManagerError.windowControlFailed(result.stderr)
        }
    }
}
