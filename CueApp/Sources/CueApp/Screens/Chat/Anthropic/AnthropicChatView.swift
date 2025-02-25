import SwiftUI
import CueAnthropic

struct StreamingMessageView: View {
    let response: String

    var body: some View {
        MessageBubble(
            message: .anthropic(
                .assistantMessage(
                    Anthropic.MessageParam(
                        role: "assistant",
                        content: [
                            Anthropic.ContentBlock.text(
                                Anthropic.TextBlock(
                                    text: response,
                                    type: "text"
                                )
                            )
                        ]
                    )
                )
            ),
            isStreaming: true
        )
    }
}

// Extract the thinking view to simplify the hierarchy
struct ThinkingView: View {
    let thinking: String

    var body: some View {
        VStack(alignment: .leading) {
            // Debug Text
            Text("Thinking exists: \(thinking.count) chars")
                .font(.caption)
                .foregroundColor(.red)

            // Actual thinking bubble
            ThinkingBubbleFixed(thinking: thinking)
        }
    }
}

public struct AnthropicChatView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var windowManager: CompanionWindowManager
    @StateObject private var viewModel: AnthropicChatViewModel
    @FocusState private var isFocused: Bool
    @Namespace private var bottomID
    @AppStorage("selectedAnthropicModel") private var storedModel: ChatModel = .claude35Sonnet
    @State private var showingToolsList = false
    @State private var isHovering = false
    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping () -> AnthropicChatViewModel, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.isCompanion = isCompanion
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack {
                messageList
                RichTextField(
                    onShowTools: {
                        showingToolsList = true
                    },
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    },
                    toolCount: viewModel.availableTools.count,
                    inputMessage: $viewModel.newMessage,
                    isFocused: $isFocused
                )
            }
            if isCompanion {
                CompanionHeaderView(isHovering: $isHovering)
            }
        }
        .withCoordinatorAlert(isCompanion: isCompanion)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
            #if os(macOS)
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Menu {
                    Button("Open companion chat") {
                        openCompanionChat(with: viewModel.model)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.primary)
                }
                .menuIndicator(.hidden)
            }
            #endif
        }
        .onAppear {
            viewModel.model = storedModel
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
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) { isHovering = hovering }
        }
        #endif
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ModelSelectorToolbar(
            currentModel: viewModel.model,
            models: ChatModel.models(for: .anthropic),
            iconView: AnyView(Provider.anthropic.iconView),
            getModelName: { $0.displayName },
            onModelSelected: { model in
                storedModel = model
                viewModel.model = model
            }
        )
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: .anthropic(message))
                    }
                    // Thinking content (if present)
                    thinkingContent

                    // Streaming response (if present)
                    streamingContent
                    // Invisible marker view at bottom
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding(.top)
            }
            #if os(macOS)
            .safeAreaInset(edge: .top) {
               if isCompanion {
                   Color.clear.frame(height: 36)
               }
            }
            #endif
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

    private var messagesContent: some View {
         ForEach(viewModel.messages) { message in
             MessageBubble(message: .anthropic(message))
         }
     }

     private var thinkingContent: some View {
         Group {
             if viewModel.isStreaming && !viewModel.streamedThinking.isEmpty {
                 ThinkingView(thinking: viewModel.streamedThinking)
                     .id("thinking-\(viewModel.streamedThinking.count)")
             }
         }
     }

     private var streamingContent: some View {
         Group {
             if viewModel.isStreaming && !viewModel.streamedResponse.isEmpty {
                 StreamingMessageView(response: viewModel.streamedResponse)
                     .id("streaming-\(viewModel.streamedResponse.count)")
             }
         }
     }

     private var bottomMarker: some View {
         Color.clear
             .frame(height: 1)
             .id(bottomID)
     }

     private func scrollToBottom(proxy: ScrollViewProxy) {
         withAnimation {
             proxy.scrollTo(bottomID, anchor: .bottom)
         }
     }

    func openCompanionChat(with model: ChatModel) {
        let config = CompanionWindowConfig(
            model: model.rawValue,
            provider: .anthropic,
            additionalSettings: [:]
        )
        windowManager.openCompanionWindow(id: UUID().uuidString, config: config)
    }
}

extension Anthropic.ChatMessageParam {
    public var id: String {
        // Create a unique identifier based on role and content
        "\(role)-\(content)".hash.description
    }
}

// 3. Update ThinkingBubble to add more debug info and ensure it always updates
struct ThinkingBubbleFixed: View {
    let thinking: String
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with expand/collapse button
            HStack {
                Label("Claude's Thinking (\(thinking.count) chars)", systemImage: "brain")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)

            // Thinking content
            if isExpanded {
                Text(thinking)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                    .id(thinking.hashValue) // Force view to update when content changes
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .onChange(of: thinking) { _, _ in
            print("Thinking content updated in bubble")
        }
    }
}

// 4. For debugging purposes, add a separate test view
struct ThinkingDebugView: View {
    @ObservedObject var viewModel: AnthropicChatViewModel

    var body: some View {
        VStack {
            Text("Debugging Thinking Display")
                .font(.headline)

            Divider()

            Text("Is Streaming: \(viewModel.isStreaming ? "Yes" : "No")")
            Text("Thinking Length: \(viewModel.streamedThinking.count) characters")
            Text("Response Length: \(viewModel.streamedResponse.count) characters")

            Divider()

            if !viewModel.streamedThinking.isEmpty {
                Text("Thinking Content Preview:")
                    .font(.subheadline)

                Text(viewModel.streamedThinking.prefix(100) + "...")
                    .font(.caption)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Text("No thinking content available")
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .frame(width: 300, height: 300)
    }
}
