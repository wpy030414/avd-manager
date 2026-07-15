import SwiftUI

/// Compact status dot.
private struct StatusDot: View {
    let state: EmulatorState

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.6), radius: 3, x: 0, y: 0)
    }

    private var color: Color {
        switch state {
        case .stopped:           return DesignTokens.Colors.neutral
        case .booting, .stopping: return DesignTokens.Colors.warning
        case .running:           return DesignTokens.Colors.success
        case .error:             return DesignTokens.Colors.error
        }
    }
}

/// Compact row — selected state uses plain accent fill, no glass overflow.
public struct AVDRowView: View {
    public let avd: AVD
    @ObservedObject public var viewModel: AVDManagerViewModel

    @State private var isHovering = false

    private var isSelected: Bool {
        viewModel.selectedAVD?.id == avd.id
    }

    public init(avd: AVD, viewModel: AVDManagerViewModel) {
        self.avd = avd
        self.viewModel = viewModel
    }

    public var body: some View {
        Button(action: {
            viewModel.selectedAVD = avd
        }) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "iphone")
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? .white : Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? Color.white.opacity(0.18) : Color.clear)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(avd.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        StatusDot(state: avd.state)
                    }

                    HStack(spacing: 4) {
                        Text("API \(avd.apiLevel)")
                            .font(.caption2)
                            .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                        if let abi = avd.abi, !abi.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                            Text(abiShortName(abi))
                                .font(.caption2)
                                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(rowFill)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var rowFill: Color {
        if isSelected { return Color.accentColor }
        if isHovering { return Color.white.opacity(0.06) }
        return Color.clear
    }

    private func abiShortName(_ abi: String) -> String {
        if abi.contains("arm64") { return "arm64" }
        if abi.contains("armeabi") { return "arm" }
        if abi.contains("x86_64") { return "x86_64" }
        if abi.contains("x86") { return "x86" }
        return abi
    }
}

#if DEBUG
#Preview {
    AVDRowView(
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
    .padding()
    .frame(width: 240)
}
#endif
