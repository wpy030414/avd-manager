import SwiftUI

/// Design tokens for AVD Manager.
/// Glass surfaces use native macOS 27 `.glassEffect()` — see `UIKit/Glass`.
/// This file holds only non-glass constants (colors, fonts, radii, spacing).
enum DesignTokens {
    enum Colors {
        static let accent = Color.accentColor
        static let primaryText = Color.primary
        static let secondaryText = Color.secondary
        static let error = Color.red
        static let success = Color.green
        static let warning = Color.orange
        static let neutral = Color.gray
    }

    enum Fonts {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 13, weight: .regular, design: .default)
        static let callout = Font.system(size: 12, weight: .medium, design: .default)
        static let caption = Font.system(size: 11, weight: .regular, design: .default)
        static let toolbar = Font.system(size: 12, weight: .semibold, design: .rounded)
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 20
        static let xl: CGFloat = 28
        static let full: CGFloat = 9999
    }

    enum Materials {
        static let sidebar = Material.ultraThinMaterial
        static let card = Material.thinMaterial
        static let sheet = Material.ultraThinMaterial
        static let toolbar = Material.bar
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
}
