import SwiftUI

/// Sheet for configuring emulator launch options.
struct EmulatorSettingsSheet: View {
    @Binding var enableKeyboard: Bool
    @Binding var enableGPU: Bool
    @Binding var showBootAnim: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("模拟器设置")
                    .font(.title2.weight(.bold))
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(.glass)
            }
            .padding()
            .background(.ultraThinMaterial)

            // Options
            VStack(alignment: .leading, spacing: 4) {
                ToggleRow(
                    icon: "keyboard",
                    title: "键盘输入",
                    subtitle: "将 Mac 键盘输入转发到模拟器（自动设置 hw.keyboard=yes）",
                    isOn: $enableKeyboard
                )
                Divider().opacity(0.3)
                ToggleRow(
                    icon: "sparkles",
                    title: "GPU 加速",
                    subtitle: "启用硬件 GPU 渲染；关闭则使用软件渲染",
                    isOn: $enableGPU
                )
                Divider().opacity(0.3)
                ToggleRow(
                    icon: "play.rectangle",
                    title: "启动动画",
                    subtitle: "显示 Android 启动动画",
                    isOn: $showBootAnim
                )
            }
            .padding(20)
        }
        .frame(width: 420)
        .background(.thinMaterial)
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
    }
}

#if DEBUG
#Preview {
    EmulatorSettingsSheet(
        enableKeyboard: .constant(true),
        enableGPU: .constant(true),
        showBootAnim: .constant(false)
    )
}
#endif
