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
        VStack(spacing: 0) {
            #if os(macOS)
            Rectangle()
                .fill(AppTheme.Colors.separator.opacity(0.5))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            #endif

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
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
            .frame(maxHeight: .infinity)

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .defaultNavigationBar(showCustomBackButton: false, title: "")
        .toolbar {
            ToolbarItem(placement: .principal) {
                #if os(iOS)
                Menu {
                    Picker("Model", selection: $viewModel.model) {
                        ForEach(ChatModel.allCases, id: \.self) { model in
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
                    ForEach(ChatModel.allCases, id: \.self) { model in
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
}
