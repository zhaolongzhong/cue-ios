import SwiftUI

public struct CueChatView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = CueChatViewModel()
    @FocusState private var isFocused: Bool
    @Namespace private var bottomID
    @State private var showingToolsList = false

    public init() {}

    public var body: some View {
        VStack {
            messageList

            RichTextField(
                showVoiceChat: true,
                showAXapp: false,
                onShowTools: {
                    showingToolsList = true
                },
                onOpenVoiceChat: {
                    #if os(macOS)
                    openWindow(id: "realtime-chat-window")
                    #else
                    coordinator.showLiveChatSheet()
                    #endif
                },
                onStartAXApp: { _ in },
                onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                },
                toolCount: viewModel.availableTools.count,
                inputMessage: $viewModel.newMessage,
                isFocused: $isFocused
            )
            .padding(.all, 8)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    Picker("Model", selection: $viewModel.model) {
                        ForEach(ChatModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(viewModel.model.displayName)
                            .font(.callout)
                            .fontWeight(.semibold)
                        #if os(iOS)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        #endif
                    }
                    .foregroundColor(.primary)
                    #if os(macOS)
                    .frame(width: 120)
                    #endif
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
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
