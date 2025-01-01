import SwiftUI
import Dependencies

class SidePanelState: ObservableObject {
    @Published var isShowing = false
    @Published var selectedAssistant: Assistant?
}

enum HomeDestination: Hashable {
    case settings
    case openai
    case anthropic
    case chat(Assistant)
}

struct HomeView: View {
    @Dependency(\.webSocketService) public var webSocketService
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @StateObject private var sidePanelState = SidePanelState()
    @State private var navigationPath = NavigationPath()
    @State private var dragOffset: CGFloat = 0
    @StateObject private var apiKeysViewModel: APIKeysViewModel

    private let sidebarWidth: CGFloat = 300
    private let dragThreshold: CGFloat = 50

    public init(apiKeysViewModelFactory: @escaping () -> APIKeysViewModel) {
        _apiKeysViewModel = StateObject(wrappedValue: apiKeysViewModelFactory())
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                WelcomeView(sidePanelState: sidePanelState)
                .withCommonNavigationBar()
                .gesture(sidePanelGesture)
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .settings:
                        SettingsView(
                            viewModelFactory: dependencies.viewModelFactory.makeSettingsViewModel
                        )
                        .withCommonNavigationBar()
                    case .openai:
                        OpenAIChatView(apiKey: apiKeysViewModel.openAIKey)
                            .withCommonNavigationBar()
                    case .anthropic:
                        AnthropicChatView(apiKey: apiKeysViewModel.anthropicKey)
                            .withCommonNavigationBar()
                    case .chat(let assistant):
                        ChatView(
                            assistant: assistant,
                            chatViewModel: dependencies.viewModelFactory.makeChatViewViewModel(assistant: assistant),
                            assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel(),
                            tag: "home"
                        )
                        .id(assistant.id)
                        .withCommonNavigationBar()
                    }
                }
            }
            .background(Color.orange)
            .environmentObject(sidePanelState)
            // Overlay layer when side panel is showing
            if sidePanelState.isShowing {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut) {
                            sidePanelState.isShowing = false
                        }
                    }
            }

            // Side Panel layer
            ZStack(alignment: .leading) {
                assistantsPanel
                    .frame(width: sidebarWidth)
                    .background(AppTheme.Colors.background)
                    .offset(x: sidePanelState.isShowing ? 0 : -sidebarWidth)
                    .animation(.easeOut, value: sidePanelState.isShowing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .background(AppTheme.Colors.secondaryBackground)
        .onAppear {
            AppLog.log.debug("AppTabView onAppear isAuthenticated:\(appStateViewModel.state.isAuthenticated)")
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }
        .onChange(of: appStateViewModel.state.currentUser) { _, _ in
            self.initialize(userId: appStateViewModel.state.currentUser?.id)
        }

    }

    private func initialize(userId: String?) {
        guard let _ = userId else {
            return
        }
        Task {
            await webSocketService.connect()
        }
    }

    private var assistantsPanel: some View {
        AssistantsSidePanel(
            assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel(),
            navigationPath: $navigationPath,
            onSelectAssistant: { assistant in
                navigationPath.append(HomeDestination.chat(assistant))
                withAnimation(.easeOut) {
                    sidePanelState.isShowing = false
                }
            },
            onOpenAIChat: {
                navigationPath.append(HomeDestination.openai)
                withAnimation(.easeOut) {
                    sidePanelState.isShowing = false
                }

            },
            onAnthropicChat: {
                navigationPath.append(HomeDestination.anthropic)
                withAnimation(.easeOut) {
                    sidePanelState.isShowing = false
                }
            }
        )
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .background(AppTheme.Colors.secondaryBackground)
        .environmentObject(sidePanelState)
        .environmentObject(apiKeysViewModel)
    }

    private var sidePanelGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                let translation = gesture.translation.width
                if (!sidePanelState.isShowing && translation > 0) ||
                   (sidePanelState.isShowing && translation < 0) {
                    dragOffset = translation
                }
            }
            .onEnded { gesture in
                let translation = gesture.translation.width
                withAnimation(.easeOut) {
                    if !sidePanelState.isShowing && translation > dragThreshold {
                        sidePanelState.isShowing = true
                    } else if sidePanelState.isShowing && -translation > dragThreshold {
                        sidePanelState.isShowing = false
                    }
                    dragOffset = 0
                }
            }
    }
}

struct AssistantsSidePanel: View {
    @EnvironmentObject private var apiKeysViewModel: APIKeysViewModel
    @EnvironmentObject private var sidePanelState: SidePanelState
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    @Binding var navigationPath: NavigationPath
    let onSelectAssistant: (Assistant) -> Void
    let onOpenAIChat: () -> Void
    let onAnthropicChat: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Section {
                if !apiKeysViewModel.openAIKey.isEmpty {
                    Button(action: onOpenAIChat) {
                        HStack(spacing: 8) {
                            Image("openai", bundle: Bundle.module)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundColor(.primary.opacity(0.9))
                            Text("OpenAI")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                }

                if !apiKeysViewModel.anthropicKey.isEmpty {
                    Button(action: onAnthropicChat) {
                        HStack(spacing: 8) {
                            Image("anthropic", bundle: Bundle.module)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundColor(.primary.opacity(0.9))

                            Text("Anthropic")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                }

            } header: {
                HStack {
                    Text("Providers")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
            }
            .padding(.trailing, 0)
            #if os(iOS)
            .listSectionSpacing(.compact)
            #endif

            Text("Assistants")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.secondary)
                .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(assistantsViewModel.assistants) { assistant in
                        AssistantRow(
                            assistant: assistant,
                            status: assistantsViewModel.getClientStatus(for: assistant),
                            actions: nil
                        )
                        .padding(.horizontal)
                        .onTapGesture {
                            onSelectAssistant(assistant)
                        }
                    }
                }
                .padding(.vertical)
            }

            HStack {
                Button(action: {
                    withAnimation(.easeOut) {
                        sidePanelState.isShowing = false
                        navigationPath.append(HomeDestination.settings)
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .frame(width: 36, height: 36)
                            .background(.secondary)
                            .clipShape(Circle())

                        Text("Settings")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .onAppear {
            Task {
                await assistantsViewModel.fetchAssistants()
            }
        }
    }
}

struct WelcomeView: View {
    let sidePanelState: SidePanelState
    var body: some View {
        ZStack {
            // Background color for the entire view
            AppTheme.Colors.secondaryBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Welcome to Cue")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Select an assistant from the menu to start chatting")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CommonNavigationBarModifier: ViewModifier {
    @EnvironmentObject private var sidePanelState: SidePanelState

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.easeOut) {
                            sidePanelState.isShowing.toggle()
                        }
                    } label: {
                        Image("menu", bundle: Bundle.module)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.primary.opacity(0.9))
                    }
                }
                #endif
            }
    }
}

extension View {
    func withCommonNavigationBar() -> some View {
        modifier(CommonNavigationBarModifier())
    }
}
