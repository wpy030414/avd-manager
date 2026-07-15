import SwiftUI

/// Environment management sheet — dependency status with inline paths, one-click install.
public struct EnvManageSheet: View {
    @ObservedObject public var viewModel: AVDManagerViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: AVDManagerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(NSLocalizedString("env_manage", comment: ""))
                    .font(.title2.weight(.bold))
                Spacer()

                Button(NSLocalizedString("done", comment: "")) {
                    dismiss()
                }
                .buttonStyle(.glass)
            }
            .padding()
            .background(.ultraThinMaterial)

            ScrollView {
                VStack(spacing: 8) {
                    depRow(
                        icon: "mug.fill",
                        label: "Homebrew",
                        installed: viewModel.dependencyStatus.brewInstalled,
                        path: viewModel.dependencyStatus.brewPath
                    )
                    depRow(
                        icon: "cup.and.saucer.fill",
                        label: "Java (OpenJDK)",
                        installed: viewModel.dependencyStatus.javaInstalled,
                        path: viewModel.dependencyStatus.javaVersion ?? viewModel.dependencyStatus.javaHome
                    )
                    depRow(
                        icon: "externaldrive.fill",
                        label: "Android SDK",
                        installed: viewModel.dependencyStatus.sdkRootInstalled,
                        path: viewModel.dependencyStatus.sdkRootPath
                    )
                    depRow(
                        icon: "gearshape.2.fill",
                        label: "avdmanager",
                        installed: viewModel.dependencyStatus.avdmanagerInstalled,
                        path: viewModel.avdmanagerPath
                    )
                    depRow(
                        icon: "gearshape.2.fill",
                        label: "sdkmanager",
                        installed: viewModel.dependencyStatus.sdkmanagerInstalled,
                        path: viewModel.sdkmanagerPath
                    )
                    depRow(
                        icon: "terminal.fill",
                        label: "adb",
                        installed: viewModel.dependencyStatus.adbInstalled,
                        path: viewModel.adbPath
                    )
                    depRow(
                        icon: "play.display",
                        label: "emulator",
                        installed: viewModel.dependencyStatus.emulatorInstalled,
                        path: viewModel.emulatorPath
                    )
                }
                .padding()
            }

            // Install button area
            if !viewModel.isInstallingDeps {
                installButtonArea
            } else {
                installProgressArea
            }
        }
        .frame(minWidth: 460, minHeight: 480)
        .background(.thinMaterial)
        .onAppear {
            viewModel.checkDependencies()
        }
    }

    // MARK: - Dependency Row (with inline path)

    private func depRow(icon: String, label: String, installed: Bool, path: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(label)
                    .font(.callout)
                    .foregroundStyle(.primary)

                Spacer()

                if installed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
            }

            if let path = path, installed {
                Text(path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 30)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Install Button

    private var installButtonArea: some View {
        VStack(spacing: 0) {
            Divider()

            if viewModel.dependencyStatus.missingCount > 0 {
                Button(action: { viewModel.installAllMissingDeps() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.to.line.compact")
                            .font(.system(size: 14, weight: .semibold))
                        Text(NSLocalizedString("env_one_click_install", comment: ""))
                            .font(.body.weight(.semibold))
                        Text("(\(viewModel.dependencyStatus.missingCount))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.glassProminent)
                .padding()
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(NSLocalizedString("env_all_deps_ready", comment: ""))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }

    // MARK: - Install Progress

    private var installProgressArea: some View {
        VStack(spacing: 0) {
            Divider()

            VStack(spacing: 10) {
                ProgressView(value: viewModel.installPercent, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)

                HStack {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                    Text(viewModel.installMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(viewModel.installPercent * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

#if DEBUG
#Preview {
    EnvManageSheet(viewModel: AVDManagerViewModel())
}
#endif
