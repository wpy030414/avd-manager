import SwiftUI

/// Emulator state badge — uses native glass effect.
public struct StateBadge: View {
    public let state: EmulatorState

    public init(state: EmulatorState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.systemImage)
                .font(.caption2)
            Text(state.localizedName)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundStyle(foregroundColor)
        .glassEffect(.clear, in: Capsule())
    }

    private var foregroundColor: Color {
        switch state {
        case .stopped:           return .secondary
        case .booting, .stopping: return .orange
        case .running:           return .green
        case .error:             return .red
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 8) {
        StateBadge(state: .stopped)
        StateBadge(state: .booting)
        StateBadge(state: .running)
        StateBadge(state: .error)
    }
    .padding()
}
#endif
