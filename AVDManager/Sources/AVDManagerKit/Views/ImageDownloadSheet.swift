import SwiftUI

/// Sheet for browsing and downloading system images — fetched live from `sdkmanager --list`.
/// Auto-refreshes on app startup if SDK is available; otherwise shows a manual refresh prompt.
public struct ImageDownloadSheet: View {
    @ObservedObject public var viewModel: AVDManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedAPI: Int = 0  // 0 = all
    @State private var deleteConfirmation: SystemImage?

    public init(viewModel: AVDManagerViewModel) {
        self.viewModel = viewModel
    }

    /// Group images by API level, apply search / API filter.
    private var filteredGroups: [(apiLevel: Int, versionLabel: String, images: [SystemImage])] {
        let allGroups = Dictionary(grouping: viewModel.systemImages) { $0.apiLevel }
        return allGroups
            .compactMap { api, images -> (Int, String, [SystemImage])? in
                let filtered = images.filter { image in
                    let matchesSearch = searchText.isEmpty
                        || image.localizedDescription.localizedCaseInsensitiveContains(searchText)
                        || "\(image.apiLevel)".contains(searchText)
                    let matchesAPI = selectedAPI == 0 || image.apiLevel == selectedAPI
                    return matchesSearch && matchesAPI
                }
                guard !filtered.isEmpty else { return nil }
                return (api, androidVersionName(for: api), filtered)
            }
            .sorted { $0.0 > $1.0 }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(NSLocalizedString("image_management", comment: ""))
                    .font(.title2.weight(.bold))
                Spacer()

                // Refresh button
                refreshToolbarButton

                Button(NSLocalizedString("done", comment: "")) {
                    dismiss()
                }
                .buttonStyle(.glass)
            }
            .padding()
            .background(.ultraThinMaterial)

            // Search & API filter
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField(NSLocalizedString("search_images_placeholder", comment: ""), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 9999))

                Picker("API", selection: $selectedAPI) {
                    Text("All").tag(0)
                    ForEach(availableAPILevels, id: \.self) { api in
                        Text("API \(api)").tag(api)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Status bar
            statusBar
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            // Content
            if viewModel.systemImages.isEmpty && !viewModel.isRefreshingImages {
                emptyState
            } else if filteredGroups.isEmpty {
                noResultsState
            } else {
                imageList
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .background(.thinMaterial)
        .alert(
            NSLocalizedString("delete_image_title", comment: ""),
            isPresented: Binding(
                get: { deleteConfirmation != nil },
                set: { if !$0 { deleteConfirmation = nil } }
            )
        ) {
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {
                deleteConfirmation = nil
            }
            Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                if let image = deleteConfirmation {
                    viewModel.deleteImage(image)
                }
                deleteConfirmation = nil
            }
        } message: {
            if let image = deleteConfirmation {
                Text(String(format: NSLocalizedString("delete_image_message", comment: ""), image.localizedDescription))
            }
        }
    }

    // MARK: - Refresh Button

    private var refreshToolbarButton: some View {
        Button {
            viewModel.refreshImagesFromSDK()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .semibold))
                .rotationEffect(.degrees(viewModel.isRefreshingImages ? 360 : 0))
                .animation(
                    viewModel.isRefreshingImages
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: viewModel.isRefreshingImages
                )
        }
        .buttonStyle(.glass)
        .disabled(viewModel.isRefreshingImages)
        .help("从 sdkmanager 刷新")
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if viewModel.isRefreshingImages {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                    Text("正在从 sdkmanager 获取…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let refreshTime = viewModel.lastImageRefresh {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("上次刷新: \(refreshTime, style: .time)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            } else {
                Text("点击 🔄 从 sdkmanager 获取镜像列表")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let error = viewModel.imageRefreshError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Empty / No Results

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(spacing: 6) {
                Text("尚未获取系统镜像")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("点击上方刷新按钮从 sdkmanager 获取可用镜像列表")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button {
                viewModel.refreshImagesFromSDK()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("立即获取")
                        .font(.body.weight(.semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
            }
            .buttonStyle(.glassProminent)
            .disabled(viewModel.isRefreshingImages)
        }
        .frame(maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("no_matching_images", comment: ""))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Image List

    private var imageList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(filteredGroups, id: \.apiLevel) { group in
                    Section {
                        ForEach(group.images) { image in
                            imageRow(image)
                        }
                    } header: {
                        sectionHeader(
                            apiLevel: group.apiLevel,
                            version: group.versionLabel,
                            count: group.images.count
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Section Header

    private func sectionHeader(apiLevel: Int, version: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text("API \(apiLevel)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(apiColor(apiLevel).gradient))

            Text(version)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Text(String(format: NSLocalizedString("image_count_format", comment: ""), count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    // MARK: - Image Row

    private func imageRow(_ image: SystemImage) -> some View {
        HStack(spacing: 12) {
            statusIndicator(image)

            VStack(alignment: .leading, spacing: 3) {
                Text("Android \(image.androidVersion) (API \(image.apiLevel))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(image.variantLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(image.abiLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            actionButton(image)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial.opacity(0.6))
        )
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func statusIndicator(_ image: SystemImage) -> some View {
        let isDownloading = (image.downloadProgress ?? 0) > 0 && (image.downloadProgress ?? 0) < 1.0
        let isInstalling = (image.installProgress ?? 0) > 0

        if isDownloading || isInstalling {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .frame(width: 24, height: 24)
        } else if image.isInstalled {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
                .frame(width: 24)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 24)
        }
    }

    @ViewBuilder
    private func actionButton(_ image: SystemImage) -> some View {
        let isDownloading = (image.downloadProgress ?? 0) > 0 && (image.downloadProgress ?? 0) < 1.0
        let isInstalling = (image.installProgress ?? 0) > 0 && (image.installProgress ?? 0) < 1.0

        if isDownloading || isInstalling {
            VStack(spacing: 4) {
                if isDownloading, let dl = image.downloadProgress {
                    dualBar(label: "下载", progress: dl)
                } else if image.downloadProgress == 1.0 {
                    dualBar(label: "下载", progress: 1.0, done: true)
                }
                if isInstalling, let inst = image.installProgress {
                    dualBar(label: "安装", progress: inst)
                }
            }
            .frame(width: 110)
        } else if image.isInstalled {
            Button {
                deleteConfirmation = image
            } label: {
                Text(NSLocalizedString("delete", comment: ""))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
        } else {
            Button {
                viewModel.downloadImage(image)
            } label: {
                Text(NSLocalizedString("download", comment: ""))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.glassProminent)
        }
    }

    private func dualBar(label: String, progress: Double, done: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green)
            } else {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(barColor(progress))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func barColor(_ progress: Double) -> Color {
        if progress >= 1.0 { return .green }
        if progress > 0.5 { return .accentColor }
        return .blue
    }

    // MARK: - Helpers

    private var availableAPILevels: [Int] {
        let levels = Set(viewModel.systemImages.map(\.apiLevel))
        return levels.sorted(by: >)
    }

    private func apiColor(_ api: Int) -> Color {
        switch api {
        case 35...: return .purple
        case 33...34: return .blue
        case 31...32: return .teal
        case 28...30: return .green
        case 24...27: return .orange
        default: return .gray
        }
    }

    /// Human-readable Android version name for a given API level.
    private func androidVersionName(for api: Int) -> String {
        switch api {
        case 37: return "17"
        case 36: return "16"
        case 35: return "15"
        case 34: return "14"
        case 33: return "13"
        case 32: return "12L"
        case 31: return "12"
        case 30: return "11"
        case 29: return "10"
        case 28: return "9 Pie"
        case 27: return "8.1 Oreo"
        case 26: return "8.0 Oreo"
        case 25: return "7.1 Nougat"
        case 24: return "7.0 Nougat"
        case 23: return "6.0 Marshmallow"
        case 22: return "5.1 Lollipop"
        case 21: return "5.0 Lollipop"
        default: return "API \(api)"
        }
    }
}

#if DEBUG
#Preview {
    ImageDownloadSheet(viewModel: AVDManagerViewModel())
}
#endif
