import SwiftUI

/// Emulator log panel embedded in the right-hand AVD pane, sitting directly
/// below the detail card and filling all remaining vertical space.
///
/// Backed by `LogStore`, which lives on the view model so this view survives
/// AVD detail-switches. Always expanded — no collapse affordance.
public struct LogPanelView: View {
    @ObservedObject private var store: LogStore

    public init(store: LogStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            logList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Emulator Log")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("\(store.entries.count)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer()

            Button(action: { store.clear() }) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("清空日志")
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(store.entries) { entry in
                        LogLineView(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .onChange(of: store.entries.count) { _, _ in
                guard let last = store.entries.last else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(isDark ? 0.55 : 0.04))
    }

    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
}

// MARK: - Single Log Line

private struct LogLineView: View {
    let storeEntry: LogStore.Entry

    init(entry: LogStore.Entry) {
        self.storeEntry = entry
    }

    var body: some View {
        Text(storeEntry.message)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    private var color: Color {
        switch storeEntry.level {
        case .info:
            return .primary
        case .output:
            return .secondary
        case .error:
            return .red
        }
    }
}

#if DEBUG
#Preview {
    LogPanelView(store: {
        let s = LogStore()
        s.append(level: .info, "▶ Starting Pixel 9 API 36...")
        s.append(level: .output, "emulator: INFO: boot completed")
        s.append(level: .info, "✓ emulator process launched on port 5554")
        return s
    }())
    .frame(width: 700, height: 320)
}
#endif
