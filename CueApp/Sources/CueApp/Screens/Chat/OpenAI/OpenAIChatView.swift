import SwiftUI
import CueOpenAI

public struct OpenAIChatView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var windowManager: CompanionWindowManager

    @StateObject private var viewModel: OpenAIChatViewModel
    @FocusState private var isFocused: Bool
    @Namespace private var bottomID
    @AppStorage("selectedOpenAIModel") private var storedModel: ChatModel = .gpt4o
    @State private var showingToolsList = false
    @State private var selectedApp: AccessibleApplication = .textEdit
    @State private var isHovering = false

    private let showAXapp: Bool
    private let isCompanion: Bool

    public init(_ viewModelFactory: @escaping () -> OpenAIChatViewModel, isCompanion: Bool = false) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
        self.isCompanion = isCompanion

        #if os(macOS)
        self.showAXapp = true
        #else
        self.showAXapp = false
        #endif
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack {
                messageList
                observedAppView
                RichTextField(
                    showVoiceChat: true,
                    showAXapp: showAXapp,
                    onShowTools: {
                        showingToolsList = true
                    },
                    onOpenVoiceChat: {
                        #if os(macOS)
                        openLiveChat()
                        #else
                        coordinator.showLiveChatSheet(.openai)
                        #endif
                    },
                    onStartAXApp: { app in
                        viewModel.updateObservedApplication(to: app)
                    },
                    onSend: {
                        Task {
                            await viewModel.sendMessage()
                        }
                    },
                    onAttachmentPicked: { attachment in
                        viewModel.addAttachment(attachment)
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
            models: ChatModel.models(for: .openai),
            iconView: AnyView(Provider.openai.iconView),
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
                        MessageBubble(message: .openAI(message))
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

    private var observedAppView: some View {
        Group {
            if let observedApp = viewModel.observedApp {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Observed app: \(observedApp.name)")
                        if let focusedLines = viewModel.focusedLines {
                            Text(focusedLines)
                        }
                    }
                    Button("Stop") {
                        viewModel.stopObserveApp()
                    }
                }
                .padding(.all, 12)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.Colors.separator))
            }
        }
    }

    func openCompanionChat(with model: ChatModel) {
        let config = CompanionWindowConfig(
            model: model.rawValue,
            provider: .openai,
            additionalSettings: [:]
        )
        windowManager.openCompanionWindow(id: UUID().uuidString, config: config)
    }

    func openLiveChat() {
        windowManager.openGeminiLiveChatWindow(id: WindowId.openaiLiveChatWindow.rawValue)
    }
}
