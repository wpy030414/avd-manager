import SwiftUI

// MARK: - Content View

public struct ContentView: View {
    @StateObject private var viewModel = AVDManagerViewModel()
    @State private var searchText = ""
    @State private var isCreatePresented = false
    @State private var isDownloadPresented = false
    @State private var isEnvPresented = false

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @AppStorage("showLog") private var showLog = true
    @Environment(\.colorScheme) private var systemColorScheme

    private var effectiveColorScheme: ColorScheme {
        appearanceMode.colorScheme ?? systemColorScheme
    }

    private var isLight: Bool {
        effectiveColorScheme == .light
    }

    public init() {}

    private var filteredAVDs: [AVD] {
        if searchText.isEmpty { return viewModel.avds }
        return viewModel.avds.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.deviceName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    public var body: some View {
        ZStack {
            FluidAmbientBackground()

            HSplitView {
                sidebar
                    .frame(minWidth: 240, idealWidth: 270, maxWidth: 360)
                    .frame(width: 270)

                rightPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .toolbar {
            ToolbarItem {
                HStack(spacing: 6) {
                    envButton
                    downloadButton
                    createButton
                    refreshButton
                }
                .padding(.horizontal, 6)
            }
            ToolbarItem {
                HStack(spacing: 6) {
                    Divider()
                        .frame(height: 20)
                    logToggle
                    appearanceToggle
                }
                .padding(.horizontal, 4)
            }
        }
        .onAppear {
            viewModel.checkSDKSetup()
        }
        .sheet(isPresented: $isCreatePresented) {
            CreateAVDSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isDownloadPresented) {
            ImageDownloadSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $isEnvPresented) {
            EnvManageSheet(viewModel: viewModel)
        }
    }

    // MARK: - Toolbar

    private var envButton: some View {
        toolbarPlain(icon: "hammer.fill", help: NSLocalizedString("env_manage", comment: ""), action: { isEnvPresented = true })
    }

    private var refreshButton: some View {
        toolbarPlain(icon: "arrow.clockwise", help: NSLocalizedString("refresh", comment: ""), action: { viewModel.refresh() })
    }

    private var downloadButton: some View {
        toolbarPlain(icon: "square.and.arrow.down", help: NSLocalizedString("image_management", comment: ""), action: { isDownloadPresented = true })
    }

    private var createButton: some View {
        toolbarPlain(icon: "plus", help: NSLocalizedString("create", comment: ""), action: { isCreatePresented = true })
    }

    private var appearanceToggle: some View {
        toolbarCircle(
            icon: isLight ? "sun.max.fill" : "moon.fill",
            help: isLight ? NSLocalizedString("appearance_dark", comment: "") : NSLocalizedString("appearance_light", comment: ""),
            action: toggleAppearance
        )
    }

    private var logToggle: some View {
        toolbarCircle(
            icon: showLog ? "terminal" : "terminal.fill",
            help: showLog ? "隐藏日志" : "显示日志",
            action: { showLog.toggle() }
        )
    }

    private func toolbarPlain(icon: String, help: String, action: @escaping () -> Void) -> some View {
        ToolbarButton(icon: icon, help: help, isGlass: false, action: action)
    }

    private func toolbarCircle(icon: String, help: String, action: @escaping () -> Void) -> some View {
        ToolbarButton(icon: icon, help: help, isGlass: true, action: action)
    }

    // MARK: - Toolbar Button (with hover effect)

    private struct ToolbarButton: View {
    let icon: String
    let help: String
    let isGlass: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .frame(width: 30, height: 30)
        .background(backgroundShape)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .help(help)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        if isGlass {
            Circle()
                .fill(.regularMaterial)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(isHovering ? 0.25 : 0.12), lineWidth: 0.5)
                )
        } else if isHovering {
            RoundedRectangle(cornerRadius: 9999, style: .continuous)
                .fill(.regularMaterial)
        }
    }
    }

    private func toggleAppearance() {
        appearanceMode = isLight ? .dark : .light
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            progressBar

            searchField
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if viewModel.avds.isEmpty {
                emptyList
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredAVDs) { avd in
                            AVDRowView(avd: avd, viewModel: viewModel)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var progressBar: some View {
        switch viewModel.setupProgress {
        case .pending:
            EmptyView()
        case .locating:
            setupIndicator(title: NSLocalizedString("setup_locating", comment: ""))
        case .verifying:
            setupIndicator(title: NSLocalizedString("setup_verifying", comment: ""))
        case .ready:
            EmptyView()
        case .error(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                Text(message)
                    .font(.caption)
                    .lineLimit(2)
                Spacer()
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.red.opacity(0.12))
        }
    }

    private func setupIndicator(title: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Search Field (pill shape)

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(NSLocalizedString("search_placeholder", comment: ""), text: $searchText)
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
    }

    // MARK: - Empty States

    private var emptyList: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("avd_list_empty", comment: ""))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyDetail: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.homebutton")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.6))
            Text(NSLocalizedString("select_avd_hint", comment: ""))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Right Pane (detail + log)

    private var rightPane: some View {
        VStack(spacing: 0) {
            if let avd = viewModel.selectedAVD {
                AVDDetailView(avd: avd, viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 0, maxHeight: 360)

                if showLog {
                    Divider()
                    LogPanelView(store: viewModel.logStore(for: avd))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                emptyDetail
            }
        }
    }
}

// MARK: - Appearance Mode

private enum AppearanceMode: String, CaseIterable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var localizedName: String {
        switch self {
        case .system: return NSLocalizedString("appearance_system", comment: "")
        case .light:  return NSLocalizedString("appearance_light", comment: "")
        case .dark:   return NSLocalizedString("appearance_dark", comment: "")
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .frame(width: 1040, height: 720)
}
#endif
