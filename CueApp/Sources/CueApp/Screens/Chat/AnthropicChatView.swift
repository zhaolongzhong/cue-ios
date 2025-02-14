import SwiftUI
import CueAnthropic

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
        .defaultNavigationBar(showCustomBackButton: false, title: "Anthropic")
        .toolbar {
            ToolbarItem(placement: .principal) {
                #if os(iOS)
                Menu {
                    Picker("Model", selection: $viewModel.model) {
                        ForEach(AnthropicModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.model.displayName)
                            .font(.headline)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                #else
                Menu {
                    ForEach(AnthropicModel.allCases, id: \.self) { model in
                        Button {
                            viewModel.model = model
                        } label: {
                            if viewModel.model == model {
                                Label(model.displayName, systemImage: "checkmark")
                            } else {
                                Text(model.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.model.displayName)
                            .font(.headline)
                    }
                    .frame(width: 120)
                    .foregroundColor(.primary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                #endif
            }
        }
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

extension Anthropic.ChatMessageParam {
    public var id: String {
        // Create a unique identifier based on role and content
        "\(role)-\(content)".hash.description
    }
}
