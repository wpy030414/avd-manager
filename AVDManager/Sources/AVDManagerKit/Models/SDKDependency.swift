import Foundation

/// Represents a host-level dependency required to run the AVD manager.
public enum SDKDependency: String, CaseIterable, Sendable {
    case commandLineTools
    case platformTools
    case emulator
    case jdk
    case buildTools
    case platform

    public var displayName: String {
        switch self {
        case .commandLineTools:
            return NSLocalizedString("dependency.cmdline.tools", comment: "Android SDK Command Line Tools")
        case .platformTools:
            return NSLocalizedString("dependency.platform.tools", comment: "Android SDK Platform Tools")
        case .emulator:
            return NSLocalizedString("dependency.emulator", comment: "Android Emulator")
        case .jdk:
            return NSLocalizedString("dependency.jdk", comment: "Java Development Kit")
        case .buildTools:
            return NSLocalizedString("dependency.build.tools", comment: "Android SDK Build Tools")
        case .platform:
            return NSLocalizedString("dependency.platform", comment: "Android SDK Platform")
        }
    }

    /// Homebrew cask name, if this dependency can be installed via `brew install --cask`.
    public var brewCask: String? {
        switch self {
        case .jdk:
            return "temurin"
        default:
            return nil
        }
    }

    /// Homebrew package name, if this dependency can be installed via `brew install`.
    public var brewPackage: String? {
        switch self {
        case .commandLineTools:
            return "android-commandlinetools"
        case .platformTools:
            return "android-platform-tools"
        default:
            return nil
        }
    }

    /// The package identifier passed to `sdkmanager`, if any.
    public var sdkmanagerPackage: String? {
        switch self {
        case .commandLineTools:
            return "cmdline-tools;latest"
        case .platformTools:
            return "platform-tools"
        case .emulator:
            return "emulator"
        case .buildTools:
            return "build-tools;35.0.0"
        case .platform:
            return "platforms;android-35"
        case .jdk:
            return nil
        }
    }

    /// Typical executable name used to verify the dependency is available on PATH.
    public var executableName: String? {
        switch self {
        case .commandLineTools:
            return "sdkmanager"
        case .platformTools:
            return "adb"
        case .emulator:
            return "emulator"
        case .jdk:
            return "java"
        case .buildTools:
            return "aapt"
        case .platform:
            return nil
        }
    }
}
