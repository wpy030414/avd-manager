import Foundation

/// Simple file-based debug logger that writes to a temp file.
enum DebugLog {
    private static let logFileURL = URL(fileURLWithPath: "/tmp/avdmanager-debug.log")

    private static let queue = DispatchQueue(label: "avdmanager.debuglog")

    static func log(_ message: String) {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        let ts = df.string(from: Date())
        let line = "[\(ts)] \(message)\n"

        // Always print to stderr as fallback
        fputs(line, stderr)

        guard let data = line.data(using: .utf8) else { return }

        queue.sync {
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            }
            if let fh = try? FileHandle(forWritingTo: logFileURL) {
                fh.seekToEndOfFile()
                fh.write(data)
                try? fh.close()
            }
        }
    }
}
