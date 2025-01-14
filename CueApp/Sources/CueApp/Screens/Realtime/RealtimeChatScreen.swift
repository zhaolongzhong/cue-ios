import SwiftUI
import CueOpenAI

public struct RealtimeChatScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var voiceChatViewModel: RealtimeChatViewModel

    public init(viewModelFactory: @escaping (String) -> RealtimeChatViewModel, apiKey: String) {
        _voiceChatViewModel = StateObject(wrappedValue: viewModelFactory(apiKey))
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                GlassmorphismParticleBackgroundView(screenSize: geometry.size)
                    .opacity(colorScheme == .dark ? 0.6 : 0.9)
                    .zIndex(0)

                VStack(spacing: 16) {
                    #if os(iOS)
                    HStack {
                        Spacer()
                        DismissButton(action: {
                            dismiss()
                        })
                    }
                    .allowsHitTesting(true)
                    .padding(.horizontal)
                    .padding(.top, geometry.safeAreaInsets.top)
                    #endif
                    Spacer()

                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(voiceChatViewModel.deltaMessage)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 48)
                                .id("messageBottom")
                        }
                        .frame(maxHeight: .infinity)
                        .onChange(of: voiceChatViewModel.deltaMessage) { _, newValue in
                            if !newValue.isEmpty {
                                withAnimation {
                                    proxy.scrollTo("messageBottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .padding(.bottom, 24)

                    controlButton
                        .padding(.bottom, 16)
                    messageInputView
                }
                .padding(.vertical)
                .zIndex(1)
            }
            .edgesIgnoringSafeArea(.all)
        }
        .onChange(of: voiceChatViewModel.chatError) { _, error in
            if let error = error {
                coordinator.showError(error.message)
                voiceChatViewModel.clearError()
            }
        }
    }

    private var messageInputView: some View {
        HStack(spacing: 12) {
            #if os(macOS)
            RoundedTextField(
                placeholder: "Type a message...",
                text: $voiceChatViewModel.newMessage,
                isDisabled: !voiceChatViewModel.state.isConnected || voiceChatViewModel.newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                voiceChatViewModel.sendMessage()
            }
            #else
            TextField("Type a message...", text: $voiceChatViewModel.newMessage)
                .customTextFieldStyle()
            #endif

            Button(action: {
                voiceChatViewModel.sendMessage()
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .disabled(!voiceChatViewModel.state.isConnected || voiceChatViewModel.newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
    }

    private var controlButton: some View {
        HStack(alignment: .center, spacing: 50) {
            // Main Control Button (Pause/Resume)
            Button(action: {
                handleMainButtonTap()
            }) {
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
            Button(action: {
                handleSessionButtonTap()
            }) {
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

    // MARK: - Button Actions
    private func handleMainButtonTap() {
        switch voiceChatViewModel.state {
        case .active:
            voiceChatViewModel.pauseChat()
        case .paused:
            voiceChatViewModel.resumeChat()
        case .error:
            // Try to recover by resetting to idle
            Task {
                await voiceChatViewModel.endChat()
                await voiceChatViewModel.startSession()
            }
        default:
            break
        }
    }

    private func handleSessionButtonTap() {
        switch voiceChatViewModel.state {
        case .idle:
            // Start new session
            Task { await voiceChatViewModel.startSession() }
        case .active, .paused, .error:
            // End current session
            Task { await voiceChatViewModel.endChat() }
        default:
            break
        }
    }

    // MARK: - Button States
    private var mainButtonIcon: String {
        switch voiceChatViewModel.state {
        case .idle, .connecting, .active:
            return "mic.fill"
        case .paused:
            return "mic.slash.fill"
        case .error:
            return "exclamationmark"
        }
    }

    private var mainButtonColor: Color {
        switch voiceChatViewModel.state {
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
        switch voiceChatViewModel.state {
        case .idle, .connecting:
            return "play"
        case .active, .paused:
            return "xmark"
        case .error:
            return "arrow.clockwise"
        }
    }

    private var isMainButtonDisabled: Bool {
        switch voiceChatViewModel.state {
        case .connecting, .idle:
            return true
        default:
            return false
        }
    }

    private var isSessionButtonDisabled: Bool {
        switch voiceChatViewModel.state {
        case .connecting:
            return true
        default:
            return false
        }
    }

    // Platform-specific sizes
    private var platformButtonSize: CGFloat {
        #if os(iOS)
        44
        #else
        36
        #endif
    }

    private var platformButtonFontSize: CGFloat {
        #if os(iOS)
        16
        #else
        14
        #endif
    }
}
