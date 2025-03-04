import SwiftUI
import CueCommon

public struct LiveChatControlButtons: View {
    let voiceState: VoiceState
    let screenSharing: ScreenSharingState
    let onMainButtonTap: () -> Void
    let onSessionButtonTap: () -> Void
    let onScreenSharingButtonTap: (() -> Void)?

    public init(
        voiceState: VoiceState,
        screenSharing: ScreenSharingState = ScreenSharingState(),
        onLeftButtonTap: @escaping () -> Void,
        onRightButtonTap: @escaping () -> Void,
        onScreenSharingButtonTap: (() -> Void)? = nil
    ) {
        self.voiceState = voiceState
        self.screenSharing = screenSharing
        self.onMainButtonTap = onLeftButtonTap
        self.onSessionButtonTap = onRightButtonTap
        self.onScreenSharingButtonTap = onScreenSharingButtonTap
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 50) {
            if screenSharing.isEnabled {
                Button {
                    onScreenSharingButtonTap?()
                } label: {
                    Group {
                        Image(systemName: screenSharing.isScreenSharing ? "video.slash.fill" :"video.fill")
                            .font(.system(size: platformButtonFontSize, weight: .bold))
                            .frame(width: platformButtonSize, height: platformButtonSize)
                            .foregroundColor(mainButtonColor)
                            .tint(screenSharing.isScreenSharing ? Color.primary : Color.gray.opacity(0.5))
                            .background(Circle()
                                .fill(AppTheme.Colors.controlButtonBackground))
                    }
                }
                .buttonStyle(.plain)
            }

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
        switch voiceState {
        case .idle, .connecting, .active:
            return "mic.fill"
        case .paused:
            return "mic.slash.fill"
        case .error:
            return "exclamationmark"
        }
    }

    private var mainButtonColor: Color {
        switch voiceState {
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
        switch voiceState {
        case .idle, .connecting:
            return "play"
        case .active, .paused:
            return "xmark"
        case .error:
            return "arrow.clockwise"
        }
    }

    private var isMainButtonDisabled: Bool {
        switch voiceState {
        case .connecting, .idle:
            return true
        default:
            return false
        }
    }

    private var isSessionButtonDisabled: Bool {
        switch voiceState {
        case .connecting:
            return true
        default:
            return false
        }
    }
}
