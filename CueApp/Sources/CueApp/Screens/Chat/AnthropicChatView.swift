import SwiftUI

public struct AnthropicChatView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel: AnthropicChatViewModel
    @FocusState private var isFocused: Bool
    @Namespace private var bottomID
    @State private var showingToolsList = false

    public init(apiKey: String) {
        _viewModel = StateObject(wrappedValue: AnthropicChatViewModel(apiKey: apiKey))
    }

    public var body: some View {
        VStack {
            messageList
            RichTextField(onShowTools: {
                showingToolsList = true
            }, onSend: {
                Task {
                    await viewModel.sendMessage()
                }
            }, toolCount: viewModel.availableTools.count, inputMessage: $viewModel.newMessage, isFocused: $isFocused)
            .padding(.all, 8)
        }
        #if os(iOS)
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    if isFocused {
                        isFocused = false
                    }
                }
        )
        #endif
        .onAppear {
            Task {
                await viewModel.startServer()
            }
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onChange(of: viewModel.error) { _, error in
            if let error = error {
                coordinator.showError(error.message)
                viewModel.clearError()
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            role: message.role,
                            content: message.content
                        )
                    }
                    // Invisible marker view at bottom
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding()
            }
            #if os(iOS)
            .simultaneousGesture(DragGesture().onChanged { _ in
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                to: nil, from: nil, for: nil)
            })
            #endif
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .sheet(isPresented: $showingToolsList) {
                ToolsListView(tools: viewModel.availableTools)
            }
        }
    }
}

extension Anthropic.ChatMessage {
    public var id: String {
        // Create a unique identifier based on role and content
        "\(role)-\(content)".hash.description
    }
}
