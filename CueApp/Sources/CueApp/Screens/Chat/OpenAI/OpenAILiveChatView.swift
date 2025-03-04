import SwiftUI
import CueOpenAI

public struct OpenAILiveChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel: OpenAILiveChatViewModel
    @FocusState private var isFocused: Bool
    @State private var showingToolsList = false
    @State private var isHovering = false
    @State private var animateDelta = false

    private let forceShowHeader: Bool
    private let isCompanion: Bool

    public init(viewModelFactory: @escaping () -> OpenAILiveChatViewModel, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.isCompanion = isCompanion
        #if os(macOS)
        self.forceShowHeader = false
        #else
        self.forceShowHeader = true
        #endif
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack {
                Spacer()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if !viewModel.deltaMessage.isEmpty {
                                Text(viewModel.deltaMessage)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("messageBottom")
                            }
                        }
                        .padding(.horizontal)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .frame(maxHeight: .infinity)
                    .onChange(of: viewModel.deltaMessage) { _, newValue in
                        if !newValue.isEmpty {
                            withAnimation {
                                proxy.scrollTo("messageBottom", anchor: .bottom)
                            }
                        }
                    }
                }
                .padding(.top, 38)

                LiveChatControlButtons(
                    voiceState: viewModel.state,
                    onLeftButtonTap: {
                        handleLeftButtonTap()
                    },
                    onRightButtonTap: {
                        handleRightButtonTap()
                    }
                )
                messageInputView
            }
            CompanionHeaderView(title: "Live Chat", isHovering: $isHovering, forceShow: forceShowHeader) {
                Task { @MainActor in
                    await viewModel.endSession()
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.startServer()
            }
        }
        .onChange(of: viewModel.chatError) { _, error in
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
    }

    private var messageInputView: some View {
        RichTextField(
            inputMessage: $viewModel.newMessage,
            isFocused: $isFocused,
            richTextFieldState: RichTextFieldState(toolCount: viewModel.availableTools.count),
            richTextFieldDelegate: richTextFieldDelegate
        )
    }

    @MainActor
    private var richTextFieldDelegate: RichTextFieldDelegate {
        ChatViewDelegate(
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
}
