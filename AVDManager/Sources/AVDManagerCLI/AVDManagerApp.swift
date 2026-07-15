import SwiftUI
import AVDManagerKit

@main
struct AVDManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .environmentObject(appDelegate.viewModel)
        }
        #if swift(>=6.0)
        .defaultSize(width: 1040, height: 720)
        #endif
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let viewModel = AVDManagerViewModel()
}
