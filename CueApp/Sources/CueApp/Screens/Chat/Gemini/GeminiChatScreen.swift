import SwiftUI
import ReplayKit
import CueGemini

public struct GeminiChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isInputFocused: Bool

    public init(apiKey: String) {
        _viewModel = StateObject(wrappedValue: GeminiChatViewModel())
        self.apiKey = apiKey
    }

    private let apiKey: String

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                GlassmorphismParticleBackgroundView(screenSize: geometry.size)
                    .opacity(colorScheme == .dark ? 0.6 : 0.9)
                    .zIndex(0)
                VStack(spacing: 16) {
                    Spacer()

                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(viewModel.messageContent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 48)
                                .id("messageBottom")
                        }
                        .frame(maxHeight: .infinity)
                        .onChange(of: viewModel.messageContent) { _, newValue in
                            if !newValue.isEmpty {
                                withAnimation {
                                    proxy.scrollTo("messageBottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .padding(.bottom, 24)

                    controlButtons
                        .padding(.bottom, 16)
                    messageInputView
                }
                .padding(.vertical)
                .zIndex(1)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    DismissButton(action: {
                        viewModel.disconnect()
                        dismiss()
                    })
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: viewModel.error) { _, error in
            if let error = error {
                // Handle error presentation
                print("Error occurred: \(error)")
                viewModel.clearError()
            }
        }
    }

    private var messageInputView: some View {
        HStack(spacing: 12) {
            #if os(macOS)
            RoundedTextField(
                placeholder: "Type a message...",
                text: $viewModel.newMessage,
                isDisabled: !viewModel.isConnected || viewModel.newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                sendMessage()
            }
            #else
            TextField("Type a message...", text: $viewModel.newMessage)
                .customTextFieldStyle()
                .focused($isInputFocused)
            #endif

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.gray)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isConnected || viewModel.newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
    }

    private var controlButtons: some View {
        HStack(alignment: .center, spacing: 50) {
            Button(action: handleConnectionButton) {
                Image(systemName: connectionButtonIcon)
                    .font(.system(size: platformButtonFontSize, weight: .bold))
                    .frame(width: platformButtonSize, height: platformButtonSize)
                    .foregroundColor(connectionButtonColor)
                    .background(Circle().fill(AppTheme.Colors.controlButtonBackground))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isConnecting)
        }
    }

    private func sendMessage() {
        Task {
            do {
                try await viewModel.sendMessage(apiKey: apiKey)
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }

    private func handleConnectionButton() {
        Task {
            if viewModel.isConnected {
                viewModel.disconnect()
            } else {
                do {
                    try await viewModel.connect(apiKey: apiKey)
                } catch {
                    print("Failed to connect: \(error)")
                }
            }
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            viewModel.handleBackgroundState()
        case .active:
            viewModel.handleActiveState()
        case .inactive:
            viewModel.handleInactiveState()
        @unknown default:
            break
        }
    }

    private var connectionButtonIcon: String {
        if viewModel.isConnecting {
            return "progress.indicator"
        } else if viewModel.isConnected {
            return "xmark"
        } else {
            return "mic"
        }
    }

    private var connectionButtonColor: Color {
        if viewModel.isConnecting {
            return .gray
        } else if viewModel.isConnected {
            return .red
        } else {
            return .gray
        }
    }
}
