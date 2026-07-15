import Foundation
import AVDManagerKit

/// Standalone debug tool — tests emulator state detection directly.
@main
struct DebugEmulator {
    static func main() async {
        print("=== DebugEmulator ===")
        print("")

        let sdk = AndroidSDK.shared
        print("[1] Detecting SDK...")
        await sdk.setupIfNeeded()

        guard let adbPath = sdk.adbPath else {
            print("❌ adb not found! sdkRoot=\(sdk.sdkRootPath ?? "nil")")
            return
        }
        print("   adb: \(adbPath)")

        let emuService = EmulatorService(sdk: sdk)
        let avdService = AVDService(sdk: sdk)

        // List AVDs
        print("\n[2] Listing AVDs...")
        guard let avds = try? await avdService.listAVDs() else {
            print("❌ Failed to list AVDs")
            return
        }
        print("   Found \(avds.count) AVD(s):")
        for avd in avds {
            print("   - \(avd.name) (API \(avd.apiLevel))")
        }

        // Check current states
        print("\n[3] Refreshing states (should show stopped)...")
        let states1 = await emuService.refreshStates(for: avds)
        for avd in states1 {
            print("   \(avd.name): \(avd.state)")
        }

        // Start the first AVD
        guard let target = avds.first else {
            print("❌ No AVD to test")
            return
        }

        print("\n[4] Starting AVD '\(target.name)'...")
        do {
            var mutableAVDs = avds
            let (_, port) = try await emuService.start(target)
            print("   Started on port \(port)")

            // Store port on the AVD (same as the ViewModel does)
            if let idx = mutableAVDs.firstIndex(where: { $0.name == target.name }) {
                mutableAVDs[idx].consolePort = port
            }

            // Poll with the same logic as the app
            print("\n[5] Polling every 1.5s for up to 60s...")
            for i in 1...40 {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                let states = await emuService.refreshStates(for: mutableAVDs)
                // Propagate ports back
                mutableAVDs = states
                if let current = states.first(where: { $0.name == target.name }) {
                    print("   [\(String(format: "%.1f", Double(i) * 1.5))s] state=\(current.state) port=\(current.consolePort?.description ?? "nil")")
                    if current.state == .running {
                        print("\n✅ SUCCESS: Emulator detected as running!")
                        break
                    }
                }
            }

            // Final state check
            print("\n[6] Final state refresh...")
            let final = await emuService.refreshStates(for: mutableAVDs)
            for avd in final {
                print("   \(avd.name): \(avd.state) port=\(avd.consolePort?.description ?? "nil")")
            }

            // Wait a bit then stop
            print("\n[7] Stopping emulator...")
            try? await emuService.stop(mutableAVDs.first(where: { $0.name == target.name }) ?? target)
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            let stopped = await emuService.refreshStates(for: mutableAVDs)
            for avd in stopped {
                print("   \(avd.name): \(avd.state)")
            }

        } catch {
            print("❌ Error: \(error)")
        }

        print("\n=== Done ===")
        exit(0)
    }
}
