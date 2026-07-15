import SwiftUI

/// macOS 27 native Liquid Glass ambient background with multi-hue color bleed.
/// Placed behind glass surfaces so light appears to pass through.
public struct FluidAmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if colorScheme == .dark {
                    Color.black.opacity(0.25)
                    darkOrbs(geometry: geometry)
                } else {
                    Color.white.opacity(0.60)
                    lightOrbs(geometry: geometry)
                }
            }
            .ignoresSafeArea()
        }
    }

    private func darkOrbs(geometry: GeometryProxy) -> some View {
        Group {
            Circle()
                .fill(Color.accentColor.opacity(0.28))
                .frame(width: geometry.size.width * 0.80)
                .blur(radius: 110)
                .offset(x: -geometry.size.width * 0.18, y: -geometry.size.height * 0.28)

            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: geometry.size.width * 0.65)
                .blur(radius: 95)
                .offset(x: geometry.size.width * 0.25, y: -geometry.size.height * 0.15)

            Circle()
                .fill(Color.teal.opacity(0.14))
                .frame(width: geometry.size.width * 0.60)
                .blur(radius: 85)
                .offset(x: geometry.size.width * 0.28, y: geometry.size.height * 0.32)

            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: geometry.size.width * 0.35)
                .blur(radius: 55)
                .offset(x: -geometry.size.width * 0.05, y: geometry.size.height * 0.08)
        }
    }

    private func lightOrbs(geometry: GeometryProxy) -> some View {
        Group {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: geometry.size.width * 0.80)
                .blur(radius: 110)
                .offset(x: -geometry.size.width * 0.18, y: -geometry.size.height * 0.28)

            Circle()
                .fill(Color.accentColor.opacity(0.10))
                .frame(width: geometry.size.width * 0.65)
                .blur(radius: 95)
                .offset(x: geometry.size.width * 0.25, y: -geometry.size.height * 0.15)

            Circle()
                .fill(Color.teal.opacity(0.07))
                .frame(width: geometry.size.width * 0.60)
                .blur(radius: 85)
                .offset(x: geometry.size.width * 0.28, y: geometry.size.height * 0.32)

            Circle()
                .fill(Color.accentColor.opacity(0.06))
                .frame(width: geometry.size.width * 0.35)
                .blur(radius: 55)
                .offset(x: -geometry.size.width * 0.05, y: geometry.size.height * 0.08)
        }
    }
}
