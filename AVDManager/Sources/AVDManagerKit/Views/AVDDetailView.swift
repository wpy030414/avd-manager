import SwiftUI

/// Detail pane — header uses glass, other sections use solid rounded rects.
/// Action buttons are circular icons inside the header card.
public struct AVDDetailView: View {
    public let avd: AVD
    @ObservedObject public var viewModel: AVDManagerViewModel
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showSettings = false

    // Emulator settings persisted per AVD
    @AppStorage("emu_keyboard") private var enableKeyboard = true
    @AppStorage("emu_gpu") private var enableGPU = true
    @AppStorage("emu_bootanim") private var showBootAnim = false

    public init(avd: AVD, viewModel: AVDManagerViewModel) {
        self.avd = avd
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                infoGrid
            }
            .padding(24)
        }
        .alert("重命名 AVD", isPresented: $isRenaming) {
            TextField("AVD 名称", text: $renameText)
            Button("取消", role: .cancel) { }
            Button("确认") {
                let newName = renameText.trimmingCharacters(in: .whitespaces)
                guard !newName.isEmpty, newName != avd.name else { return }
                viewModel.rename(avd: avd, to: newName)
            }
        } message: {
            Text("输入新名称（仅支持字母、数字、下划线、连字符和空格）")
        }
        .sheet(isPresented: $showSettings) {
            EmulatorSettingsSheet(
                enableKeyboard: $enableKeyboard,
                enableGPU: $enableGPU,
                showBootAnim: $showBootAnim
            )
        }
    }

    /// Current settings derived from AppStorage.
    private var currentSettings: EmulatorLaunchSettings {
        EmulatorLaunchSettings(
            enableKeyboard: enableKeyboard,
            enableGPU: enableGPU,
            showBootAnim: showBootAnim
        )
    }

    // MARK: - Header Card (glass + action icon buttons)

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                Image(systemName: "iphone")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 88, height: 88)
                    .glassEffect(.regular, in: Circle())

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(avd.name)
                            .font(.largeTitle)
                            .foregroundStyle(.primary)

                        // Rename button
                        Button {
                            renameText = avd.name
                            isRenaming = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("重命名")
                    }
                    StateBadge(state: avd.state)
                }

                Spacer()

                // Circular icon action buttons
                HStack(spacing: 10) {
                    if avd.state == .running {
                        circularButton(icon: "stop.fill", tint: .red, help: NSLocalizedString("stop", comment: ""), action: {
                            DebugLog.log("stop button tapped for \(avd.name)")
                            viewModel.stop(avd: avd)
                        })
                    } else if avd.state == .booting || avd.state == .stopping {
                        circularButton(icon: "xmark", tint: .orange, help: "中止", action: {
                            DebugLog.log("abort button tapped for \(avd.name)")
                            viewModel.stop(avd: avd)
                        })
                    } else {
                        circularButton(icon: "play.fill", tint: nil, help: NSLocalizedString("start", comment: ""), action: {
                            DebugLog.log("start button tapped for \(avd.name), state=\(avd.state)")
                            viewModel.start(avd: avd, settings: currentSettings)
                        })
                    }
                    circularButton(icon: "gearshape", tint: nil, help: "模拟器设置", action: { showSettings = true })
                    circularButton(icon: "trash", tint: .red, help: NSLocalizedString("delete", comment: ""), action: { viewModel.delete(avd: avd) })
                }
            }
        }
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
    }

    private func circularButton(icon: String, tint: Color?, help: String, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .scaleEffect(0.65)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint ?? Color.accentColor)
                }
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .frame(width: 36, height: 36)
        .glassEffect(.regular, in: Circle())
        .disabled(isLoading)
        .help(help)
    }

    // MARK: - Info Grid (solid rounded rects)

    private var infoGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                InfoTile(title: NSLocalizedString("detail_device", comment: ""), value: avd.deviceName ?? "—")
                InfoTile(title: NSLocalizedString("detail_abi", comment: ""), value: avd.abi ?? "—")
                InfoTile(title: NSLocalizedString("detail_target", comment: ""), value: avd.target ?? "—")
                InfoTile(title: NSLocalizedString("detail_api", comment: ""), value: String(avd.apiLevel))
            }
            GridRow {
                InfoTile(title: NSLocalizedString("detail_path", comment: ""), value: avd.path ?? "—")
                    .gridCellColumns(2)
                InfoTile(title: NSLocalizedString("detail_size", comment: ""), value: formattedSize)
                InfoTile(title: NSLocalizedString("detail_last_boot", comment: ""), value: formattedLastBoot)
            }
        }
    }

    private var formattedSize: String {
        guard let size = avd.directorySize, size > 0 else { return "—" }
        let bytes = Double(size)
        if bytes >= 1_000_000_000 {
            return String(format: "%.1f GB", bytes / 1_000_000_000)
        }
        return String(format: "%.0f MB", bytes / 1_000_000)
    }

    private var formattedLastBoot: String {
        guard let date = avd.lastBootTime else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Info Tile (solid, no glass)

private struct InfoTile: View {
    let title: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tileFill)
        )
    }

    private var tileFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(.regularMaterial)
        }
        return AnyShapeStyle(Color.white.opacity(0.50))
    }
}

#if DEBUG
#Preview {
    AVDDetailView(
        avd: AVD(
            name: "Pixel 9 API 36",
            deviceName: "pixel_9",
            target: "Android 16.0",
            apiLevel: 36,
            abi: "arm64-v8a",
            skin: "pixel_9",
            state: .running
        ),
        viewModel: AVDManagerViewModel()
    )
}
#endif
