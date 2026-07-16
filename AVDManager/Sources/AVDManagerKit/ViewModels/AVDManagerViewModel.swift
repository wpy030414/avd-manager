import Foundation
import AppKit

/// Central view model — wires the service layer to the UI.
@MainActor
public final class AVDManagerViewModel: ObservableObject {
    @Published public var avds: [AVD] = []
    @Published public var systemImages: [SystemImage] = []    // images fetched from sdkmanager
    @Published public var selectedAVD: AVD?
    @Published public var setupProgress: SetupProgress = .pending
    @Published public var isRefreshingImages = false
    @Published public var lastImageRefresh: Date?
    @Published public var imageRefreshError: String?

    // MARK: - Services

    private let sdk = AndroidSDK.shared
    private lazy var avdService = AVDService(sdk: sdk)
    private lazy var emulatorService = EmulatorService(sdk: sdk)
    private lazy var imageService = SystemImageService(sdk: sdk)

    // MARK: - Setup

    public enum SetupProgress: Sendable {
        case pending
        case locating
        case verifying
        case ready
        case error(String)
    }

    public init() {}

    func checkSDKSetup() {
        DebugLog.log("checkSDKSetup() start, sdkRoot=\(sdk.sdkRootPath ?? "nil")")
        setupProgress = .locating
        Task {
            await sdk.setupIfNeeded()
            DebugLog.log("setupIfNeeded done, sdkRoot=\(sdk.sdkRootPath ?? "nil")")
            if sdk.sdkRoot != nil {
                setupProgress = .ready
                await loadData()
                refreshImagesFromSDK()
                startAutoRefresh()
            } else {
                DebugLog.log("SDK not found!")
                setupProgress = .error("Android SDK not found. Install via Homebrew or set ANDROID_HOME.")
            }
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        do {
            async let loadedAVDs = avdService.listAVDs()
            let rawAVDs = try await loadedAVDs
            DebugLog.log("loaded \(rawAVDs.count) AVDs: \(rawAVDs.map(\.name))")

            let refreshed = await emulatorService.refreshStates(for: rawAVDs)

            avds = refreshed.map { avd in
                var enriched = avd
                if enriched.path == nil {
                    let home = sdk.sdkRootPath ?? FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Library/Android/sdk").path
                    enriched.path = "\(home)/../.android/avd/\(avd.name).avd"
                }
                return enriched
            }
            DebugLog.log("avds array updated, count=\(avds.count), first state=\(avds.first?.state.rawValue ?? "nil")")
        } catch {
            DebugLog.log("loadData FAILED: \(error.localizedDescription)")
            setupProgress = .error(error.localizedDescription)
        }
    }

    /// Fetch system images from sdkmanager in real time. Cached in `systemImages`.
    func refreshImagesFromSDK() {
        isRefreshingImages = true
        imageRefreshError = nil
        Task {
            do {
                let images = try await imageService.listImages()
                systemImages = images
                lastImageRefresh = Date()
            } catch {
                imageRefreshError = error.localizedDescription
            }
            isRefreshingImages = false
        }
    }

    func refresh() {
        Task {
            await loadData()
            refreshImagesFromSDK()
        }
    }

    // MARK: - AVD Actions

    func start(avd: AVD, settings: EmulatorLaunchSettings = .init()) {
        DebugLog.log("start() called for AVD: \(avd.name), state: \(avd.state)")
        let logStore = logStore(for: avd)
        logStore.append(level: .info, "▶ Starting \(avd.name)...")
        updateState(for: avd.id, to: .booting)
        DebugLog.log("state updated to booting, emuPath=\(emulatorPath ?? "nil")")
        // Capture weakly so the closure is safe to pass across to the actor service.
        let onLog: @Sendable (String) -> Void = { line in
            Task { @MainActor in
                logStore.append(level: .output, line)
            }
        }
        Task {
            do {
                DebugLog.log("launching emulator for: \(avd.name)")
                let (_, port) = try await emulatorService.start(avd, settings: settings, onLog: onLog)
                DebugLog.log("emulator launched on port: \(port)")
                logStore.append(level: .info, "✓ emulator process launched on port \(port)")
                // Store the port immediately so matching works
                if let idx = avds.firstIndex(where: { $0.id == avd.id }) {
                    avds[idx].consolePort = port
                }
                // Briefly wait then refresh to pick up the ADB connection
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let refreshed = await emulatorService.refreshStates(for: avds)
                for updated in refreshed {
                    updateState(for: updated.id, to: updated.state)
                }
                // Poll until fully booted
                do {
                    try await emulatorService.waitForBoot(avdName: avd.name, timeoutSeconds: 180)
                    updateState(for: avd.id, to: .running)
                    logStore.append(level: .info, "✓ \(avd.name) boot completed")
                } catch {
                    // If boot polling fails, do a final refresh to get current state
                    let final = await emulatorService.refreshStates(for: avds)
                    for updated in final {
                        updateState(for: updated.id, to: updated.state)
                    }
                    logStore.append(level: .error, "✗ boot polling failed: \(error.localizedDescription)")
                }
            } catch {
                DebugLog.log("start FAILED: \(error.localizedDescription)")
                logStore.append(level: .error, "✗ start failed: \(error.localizedDescription)")
                updateState(for: avd.id, to: .error)
                setupProgress = .error(error.localizedDescription)
            }
        }
    }

    func stop(avd: AVD) {
        updateState(for: avd.id, to: .stopping)
        logStore(for: avd).append(level: .info, "■ Stopping \(avd.name)...")
        // Look up current state from array (port may have been updated after start)
        let current = avds.first(where: { $0.id == avd.id }) ?? avd
        Task {
            do {
                try await emulatorService.stop(current)
                // Brief wait then refresh to confirm stopped
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                let refreshed = await emulatorService.refreshStates(for: avds)
                for updated in refreshed {
                    updateState(for: updated.id, to: updated.state)
                }
                logStore(for: avd).append(level: .info, "✓ \(avd.name) stopped")
            } catch {
                // Even on error, refresh to get real state
                let refreshed = await emulatorService.refreshStates(for: avds)
                for updated in refreshed {
                    updateState(for: updated.id, to: updated.state)
                }
                logStore(for: avd).append(level: .error, "✗ stop failed: \(error.localizedDescription)")
                if current.state != .stopped {
                    setupProgress = .error(error.localizedDescription)
                }
            }
        }
    }

    func delete(avd: AVD) {
        Task {
            do {
                try await avdService.deleteAVD(name: avd.name)
                avds.removeAll { $0.id == avd.id }
                if selectedAVD?.id == avd.id { selectedAVD = nil }
                logStores.removeValue(forKey: avd.id)
            } catch {
                setupProgress = .error(error.localizedDescription)
            }
        }
    }

    func rename(avd: AVD, to newName: String) {
        let oldName = avd.name
        Task {
            do {
                try await avdService.renameAVD(from: oldName, to: newName)
                // Update local state
                if let index = avds.firstIndex(where: { $0.id == avd.id }) {
                    avds[index].name = newName
                    if selectedAVD?.id == avd.id { selectedAVD = avds[index] }
                }
            } catch {
                setupProgress = .error(error.localizedDescription)
            }
        }
    }

    func create(name: String, systemImage: SystemImage, skin: String) async {
        do {
            let avd = try await avdService.createAVD(name: name, package: systemImage.package, device: skin)
            var newAVD = avd
            newAVD.skin = skin
            newAVD.path = "~/.android/avd/\(name.replacingOccurrences(of: " ", with: "_")).avd"
            avds.append(newAVD)
            await loadData()
        } catch {
            setupProgress = .error(error.localizedDescription)
        }
    }

    // MARK: - Image Management

    func deleteImage(_ image: SystemImage) {
        guard let index = systemImages.firstIndex(where: { $0.id == image.id }) else { return }
        systemImages[index].downloadProgress = 0.0
        Task {
            do {
                try await imageService.uninstall(package: image.package)
                systemImages[index].isInstalled = false
                systemImages[index].downloadProgress = nil
                systemImages[index].installProgress = nil
            } catch {
                systemImages[index].downloadProgress = nil
                setupProgress = .error(error.localizedDescription)
            }
        }
    }

    func downloadImage(_ image: SystemImage) {
        guard let index = systemImages.firstIndex(where: { $0.id == image.id }) else { return }
        systemImages[index].downloadProgress = 0.0
        systemImages[index].installProgress = nil
        Task {
            do {
                let stream = try await imageService.download(package: image.package)
                for await progress in stream {
                    guard let i = systemImages.firstIndex(where: { $0.id == image.id }) else { break }

                    switch progress.phase {
                    case .downloading:
                        systemImages[i].downloadProgress = progress.percent
                    case .installing:
                        systemImages[i].downloadProgress = 1.0  // download done
                        systemImages[i].installProgress = progress.percent
                    case .complete:
                        systemImages[i].downloadProgress = nil
                        systemImages[i].installProgress = nil
                        systemImages[i].isInstalled = true
                    }

                    if let error = progress.errorMessage {
                        setupProgress = .error(error)
                    }
                }
            } catch {
                guard let i = systemImages.firstIndex(where: { $0.id == image.id }) else { return }
                systemImages[i].downloadProgress = nil
                systemImages[i].installProgress = nil
                setupProgress = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Dependency Management

    @Published public var dependencyStatus: DependencyStatus = .init()
    @Published public var isInstallingDeps = false
    @Published public var installMessage: String = ""
    @Published public var installPercent: Double = 0

    /// Per-AVD emulator startup logs, keyed by AVD id.
    /// Each AVD keeps its own log so switching the detail view shows that
    /// AVD's output rather than a shared history.
    @MainActor
    private var logStores: [UUID: LogStore] = [:]

    /// Returns the log store for a given AVD, creating one on first access.
    @MainActor
    public func logStore(for avd: AVD) -> LogStore {
        if let existing = logStores[avd.id] {
            return existing
        }
        let store = LogStore()
        logStores[avd.id] = store
        return store
    }

    func checkDependencies() {
        dependencyStatus = sdk.checkDependencies()
    }

    func installAllMissingDeps() {
        isInstallingDeps = true
        installPercent = 0
        Task {
            do {
                try await sdk.installAllMissing()
                dependencyStatus = sdk.checkDependencies()
                if sdk.sdkRoot != nil {
                    setupProgress = .ready
                    await loadData()
                    refreshImagesFromSDK()
                }
            } catch {
                installMessage = error.localizedDescription
            }
            isInstallingDeps = false
        }

        // Observe SDK progress
        Task {
            while isInstallingDeps {
                installMessage = sdk.installMessage
                installPercent = sdk.installPercent
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    // MARK: - Environment paths

    var sdkRootPath: String? { sdk.sdkRootPath }
    var adbPath: String? { sdk.adbPath }
    var emulatorPath: String? { sdk.emulatorPath }
    var avdmanagerPath: String? { sdk.avdmanagerPath }
    var sdkmanagerPath: String? { sdk.sdkmanagerPath }

    // MARK: - Auto-Refresh

    private var autoRefreshTask: Task<Void, Never>?

    private func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)  // every 5s
                guard !Task.isCancelled else { break }
                let refreshed = await emulatorService.refreshStates(for: avds)
                for updated in refreshed {
                    updateState(for: updated.id, to: updated.state)
                    if let port = updated.consolePort {
                        if let idx = avds.firstIndex(where: { $0.id == updated.id }) {
                            avds[idx].consolePort = port
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func updateState(for id: UUID, to state: EmulatorState) {
        guard let index = avds.firstIndex(where: { $0.id == id }) else { return }
        avds[index].state = state
        if selectedAVD?.id == id { selectedAVD = avds[index] }
    }

}
