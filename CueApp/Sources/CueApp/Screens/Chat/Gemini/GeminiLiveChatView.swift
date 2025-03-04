import SwiftUI
import CueGemini

public struct GeminiLiveChatView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isFocused: Bool
    @State private var showingToolsList = false
    @State private var isHovering = false
    @State private var richTextFieldState: RichTextFieldState
    private var forceShowHeader: Bool = false

    public init(viewModelFactory: @escaping () -> GeminiChatViewModel) {
        let viewModel = viewModelFactory()
        _viewModel = StateObject(wrappedValue: viewModel)
        #if os(macOS)
        forceShowHeader = false
        #else
        forceShowHeader = true
        #endif
        richTextFieldState = RichTextFieldState(toolCount: viewModel.availableTools.count)
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 16) {
                Spacer()
                HStack(spacing: 12) {
                    VStack(alignment: .center, spacing: 8) {
                        PulsingCircle(color: .blue, size: 10)
                            .padding(.trailing, 4)
                            .opacity(viewModel.isSpeaking ? 1 : 0)

                        Button {
                            Task {
                                await viewModel.interrupt()
                            }
                        } label: {
                            Text("Interrupt")
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.plain)
                        .tint(Color.gray.opacity(0.6))
                        .opacity(viewModel.isSpeaking ? 1 : 0)
                        .disabled(!viewModel.isSpeaking)
                    }
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isSpeaking)
                }
                .padding()

                LiveChatControlButtons(
                    voiceState: viewModel.state,
                    screenSharing: viewModel.screenSharingState,
                    onLeftButtonTap: handleLeftButtonTap,
                    onRightButtonTap: handleRightButtonTap,
                    onScreenSharingButtonTap: handleScreenSharingButtonTap
                )
                messageInputView
            }
            CompanionHeaderView(title: "Live Chat", isHovering: $isHovering, forceShow: forceShowHeader) {
                Task {
                    await viewModel.endSession()
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.startServer()
            }
        }
        .withCoordinatorAlert(isCompanion: true)
        .onChange(of: viewModel.error) { _, error in
            if let error = error {
                coordinator.showError(error.message)
                viewModel.clearError()
            }
        }
        .sheet(isPresented: $showingToolsList) {
            ToolsListView(tools: viewModel.availableTools)
        }
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering }
        }
        #endif
        .alert("Screen Capture Permission Required", isPresented: $viewModel.showPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Settings") {
                openSystemSettings()
            }
        } message: {
            #if os(macOS)
            Text("To share your screen, the app needs permission to record your screen. Please go to System Settings > Privacy & Security > Screen Recording and enable permission.")
            #else
            Text("To share your screen, the app needs Screen Recording permission. Please go to Settings > Privacy > Screen Recording and enable permission .")
            #endif
        }
    }

    private var messageInputView: some View {
        RichTextField(
            inputMessage: $viewModel.newMessage,
            isFocused: $isFocused,
            richTextFieldState: richTextFieldState,
            richTextFieldDelegate: richTextFieldDelegate
        )
    }

    @MainActor
    private var richTextFieldDelegate: RichTextFieldDelegate {
        ChatViewDelegate(
            chatViewModel: viewModel,
            showToolsAction: {
                showingToolsList = true
            },
            sendAction: {
                Task {
                    await viewModel.sendMessage()
                }
            }
        )
    }

    // MARK: - Button Actions
    private func handleLeftButtonTap() {
        switch viewModel.state {
        case .active:
            viewModel.pauseChat()
        case .paused:
            viewModel.resumeChat()
        case .error:
            Task {
                await viewModel.endSession()
                await viewModel.startSession()
            }
        default:
            break
        }
    }

    private func handleRightButtonTap() {
        switch viewModel.state {
        case .idle:
            Task { await viewModel.startSession() }
        case .active, .paused, .error:
            Task { await viewModel.endSession() }
        default:
            break
        }
    }

    private func handleScreenSharingButtonTap() {
        Task {
            if viewModel.screenSharingState.isScreenSharing {
                await viewModel.stopScreenCapture()
            } else {
                await viewModel.startScreenCapture()
            }
        }
    }

    private func openSystemSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

struct PulsingCircle: View {
    let color: Color
    let size: CGFloat

    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.8)
            )
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}
