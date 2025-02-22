import SwiftUI
import CueGemini

public struct GeminiChatView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var windowManager: CompanionWindowManager
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isFocused: Bool
    @Namespace private var bottomID
    @AppStorage("selectedGeminiModel") private var storedModel: ChatModel = .gemini20FlashExp
    @State private var showingToolsList = false
    @State private var isHovering = false

    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping () -> GeminiChatViewModel, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.isCompanion = isCompanion
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 16) {
                messageList
                RichTextField(showVoiceChat: true, onShowTools: {
                    showingToolsList = true
                }, onOpenVoiceChat: {
                    #if os(macOS)
                    openLiveChat()
                    #else
                    coordinator.showLiveChatSheet(.gemini)
                    #endif
                }, onSend: {
                    Task {
                        await viewModel.sendMessage()
                    }
                }, toolCount: viewModel.availableTools.count, inputMessage: $viewModel.newMessage, isFocused: $isFocused)
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
            models: ChatModel.models(for: .gemini),
            iconView: AnyView(Provider.gemini.iconView),
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
                    ForEach(viewModel.messageParmas) { message in
                        MessageBubble(message: .gemini(message))
                    }
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
        }
    }

    func openCompanionChat(with model: ChatModel) {
        let config = CompanionWindowConfig(
            model: model.rawValue,
            provider: .gemini,
            additionalSettings: [:]
        )
        windowManager.openCompanionWindow(id: UUID().uuidString, config: config)
    }

    func openLiveChat() {
        windowManager.openGeminiLiveChatWindow(id: WindowId.geminiLiveChatWindow.rawValue)
    }
}
