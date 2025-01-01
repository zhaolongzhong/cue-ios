import SwiftUI
import CueOpenAI

public struct OpenAIChatView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel: OpenAIChatViewModel
    @FocusState private var isFocused: Bool
    @Namespace private var bottomID
    @State private var showingToolsList = false
    @State private var showingVoiceChat = false

    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
        _viewModel = StateObject(wrappedValue: OpenAIChatViewModel(apiKey: apiKey))
    }

    public var body: some View {
        VStack {
            messageList
            RichTextField(showVoiceChat: true, onShowTools: {
                showingToolsList = true
            }, onOpenVoiceChat: {
                #if os(macOS)
                openWindow(id: "realtime-chat-window")
                #else
                showingVoiceChat = true
                #endif
            }, onSend: {
                Task {
                    await viewModel.sendMessage()
                }
            }, toolCount: viewModel.availableTools.count, inputMessage: $viewModel.newMessage, isFocused: $isFocused)
            .padding(.all, 8)
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
        .sheet(isPresented: $showingToolsList) {
            ToolsListView(tools: viewModel.availableTools)
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
        .navigationTitle("OpenAI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(isPresented: $showingVoiceChat) {
            RealtimeChatScreen(
                viewModelFactory: dependencies.viewModelFactory.makeRealtimeChatViewModel,
                apiKey: apiKey
            )
        }
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
        }
    }
}
