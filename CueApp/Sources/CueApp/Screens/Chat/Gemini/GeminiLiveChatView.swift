import SwiftUI
import CueGemini

public struct GeminiLiveChatView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isFocused: Bool
    @State private var showingToolsList = false
    @State private var isHovering = false
    private var forceShowHeader: Bool = false

    public init(viewModelFactory: @escaping () -> GeminiChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        #if os(macOS)
        forceShowHeader = false
        #else
        forceShowHeader = true
        #endif
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 16) {
                Spacer()
                LiveChatControlButtons(
                    state: viewModel.state,
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
    }

    private var messageInputView: some View {
        RichTextField(onShowTools: {
            showingToolsList = true
        }, onSend: {
            Task {
                await viewModel.sendMessage()
            }
        },
       toolCount: viewModel.availableTools.count, inputMessage: $viewModel.newMessage, isFocused: $isFocused)
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
