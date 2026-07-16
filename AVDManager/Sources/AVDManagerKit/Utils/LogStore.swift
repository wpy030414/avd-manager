import Foundation
import SwiftUI

/// In-memory log store for emulator startup output.
///
/// Lives at the app level (owned by `AVDManagerViewModel`) so that switching
/// the AVD detail view does NOT reset it. Logs are cleared on app exit because
/// `AVDManagerViewModel` is recreated each launch.
@MainActor
public final class LogStore: ObservableObject {
    public enum Level: String, Sendable {
        case info      // lifecycle events (start/stop/boot)
        case output    // raw emulator stdout/stderr
        case error     // failures
    }

    public struct Entry: Identifiable, Sendable {
        public let id: UUID
        public let timestamp: Date
        public let level: Level
        public let message: String

        public init(id: UUID = UUID(), timestamp: Date, level: Level, message: String) {
            self.id = id
            self.timestamp = timestamp
            self.level = level
            self.message = message
        }
    }

    @Published public private(set) var entries: [Entry] = []

    private let maxEntries = 2000
    private let dateFormatter: DateFormatter

    public init() {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        self.dateFormatter = f
    }

    /// Append a line. Safe to call from any thread — hops to MainActor.
    public func append(level: Level, _ message: String) {
        let ts = dateFormatter.string(from: Date())
        let stamped = "[\(ts)] \(message)"
        let entry = Entry(timestamp: Date(), level: level, message: stamped)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public func clear() {
        entries.removeAll()
    }
}
