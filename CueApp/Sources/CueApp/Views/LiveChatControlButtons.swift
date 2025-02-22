import SwiftUI
import CueCommon

public struct LiveChatControlButtons: View {
    let state: VoiceState
    let onMainButtonTap: () -> Void
    let onSessionButtonTap: () -> Void

    public init(
        state: VoiceState,
        onLeftButtonTap: @escaping () -> Void,
        onRightButtonTap: @escaping () -> Void
    ) {
        self.state = state
        self.onMainButtonTap = onLeftButtonTap
        self.onSessionButtonTap = onRightButtonTap
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 50) {
            // Main Control Button (Pause/Resume)
            Button {
                onMainButtonTap()
            } label: {
                Image(systemName: mainButtonIcon)
                    .font(.system(size: platformButtonFontSize, weight: .bold))
                    .frame(width: platformButtonSize, height: platformButtonSize)
                    .foregroundColor(mainButtonColor)
                    .background(Circle()
                        .fill(AppTheme.Colors.controlButtonBackground))
            }
            .buttonStyle(.plain)
            .disabled(isMainButtonDisabled)

            // Session Control Button
            Button {
                onSessionButtonTap()
            } label: {
                Image(systemName: sessionButtonIcon)
                    .font(.system(size: platformButtonFontSize, weight: .bold))
                    .frame(width: platformButtonSize, height: platformButtonSize)
                    .background(Circle()
                        .fill(AppTheme.Colors.controlButtonBackground))
            }
            .buttonStyle(.plain)
            .disabled(isSessionButtonDisabled)
        }
    }

    // MARK: - Button States
    private var mainButtonIcon: String {
        switch state {
        case .idle, .connecting, .active:
            return "mic.fill"
        case .paused:
            return "mic.slash.fill"
        case .error:
            return "exclamationmark"
        }
    }

    private var mainButtonColor: Color {
        switch state {
        case .idle, .connecting:
            return AppTheme.Colors.controlButtonDisabledForeground
        case .active:
            return .primary
        case .paused:
            return .red
        case .error:
            return .red
        }
    }

    private var sessionButtonIcon: String {
        switch state {
        case .idle, .connecting:
            return "play"
        case .active, .paused:
            return "xmark"
        case .error:
            return "arrow.clockwise"
        }
    }

    private var isMainButtonDisabled: Bool {
        switch state {
        case .connecting, .idle:
            return true
        default:
            return false
        }
    }

    private var isSessionButtonDisabled: Bool {
        switch state {
        case .connecting:
            return true
        default:
            return false
        }
    }
}
