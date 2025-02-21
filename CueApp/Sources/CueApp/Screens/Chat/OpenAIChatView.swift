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
    @State private var selectedApp: AccessibleApplication = .textEdit
    @AppStorage("selectedOpenAIModel") private var storedModel: ChatModel = .gpt4o

    private let apiKey: String
    private let showAXapp: Bool

    public init(apiKey: String) {
        self.apiKey = apiKey
        _viewModel = StateObject(wrappedValue: OpenAIChatViewModel(apiKey: apiKey))
        #if os(macOS)
        self.showAXapp = true
        #else
        self.showAXapp = false
        #endif
    }

    public var body: some View {
        VStack {
            messageList
            observedAppView
            RichTextField(showVoiceChat: true, showAXapp: showAXapp, onShowTools: {
                showingToolsList = true
            }, onOpenVoiceChat: {
                #if os(macOS)
                openWindow(id: "realtime-chat-window")
                #else
                coordinator.showLiveChatSheet()
                #endif
            }, onStartAXApp: { app in
                viewModel.updateObservedApplication(to: app)
            },
              onSend: {
                Task {
                    await viewModel.sendMessage()
                }
            },
            toolCount: viewModel.availableTools.count, inputMessage: $viewModel.newMessage, isFocused: $isFocused)
            .padding(.all, 8)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            toolbarContent
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
}
