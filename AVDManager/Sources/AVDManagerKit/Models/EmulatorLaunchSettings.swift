import Foundation

/// Per-launch settings for the Android emulator.
public struct EmulatorLaunchSettings: Sendable, Equatable {
    public var enableKeyboard: Bool   // -use-keycode-forwarding + hw.keyboard=yes
    public var enableGPU: Bool        // skip -gpu swiftshader_indirect
    public var showBootAnim: Bool     // skip -no-boot-anim

    public init(
        enableKeyboard: Bool = true,
        enableGPU: Bool = true,
        showBootAnim: Bool = false
    ) {
        self.enableKeyboard = enableKeyboard
        self.enableGPU = enableGPU
        self.showBootAnim = showBootAnim
    }

    /// Build the extra emulator arguments for these settings.
    public var arguments: [String] {
        var args: [String] = []
        // Keyboard forwarding via keycode translation
        if enableKeyboard {
            args.append("-use-keycode-forwarding")
        }
        // GPU: use software renderer when GPU is disabled
        if !enableGPU {
            args.append("-gpu")
            args.append("swiftshader_indirect")
        }
        // Boot animation
        if !showBootAnim {
            args.append("-no-boot-anim")
        }
        return args
    }
}
