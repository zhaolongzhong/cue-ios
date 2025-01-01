import SwiftUI

// MARK: - Navigation
enum HomeDestination: Hashable {
    case openai
    case anthropic
    case chat(Assistant)
}

struct HomeView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var apiKeysViewModel: APIKeysViewModel
    @StateObject private var viewModel: HomeViewModel
    @StateObject private var sidePanelState = SidePanelState()
    @State private var dragOffset: CGFloat = 0

    private let sidebarWidth: CGFloat = 300
    private let dragThreshold: CGFloat = 50

    init(userId: String) {
        let homeViewModel = HomeViewModel(userId: userId)
        _viewModel = StateObject(wrappedValue: homeViewModel)
    }

    var body: some View {
        ZStack {
            mainContent
            overlayLayer
            sidePanel
        }
        .gesture(sidePanelGesture)
        .background(AppTheme.Colors.secondaryBackground)
        .onAppear {
            Task {
                await viewModel.initialize()
            }
        }
    }
}

// MARK: - Home View Components
private extension HomeView {
    var mainContent: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            HomeDefaultView(sidePanelState: sidePanelState)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(AppTheme.Colors.secondaryBackground)
                .withCommonNavigationBar()
                .navigationDestination(for: HomeDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .environmentObject(sidePanelState)
    }

    var overlayLayer: some View {
        Color.black
            .opacity(sidePanelState.isShowing ? 0.3 : 0)
            .animation(.easeOut, value: sidePanelState.isShowing)
            .ignoresSafeArea()
            .allowsHitTesting(sidePanelState.isShowing)
            .onTapGesture { sidePanelState.hidePanel() }
    }

    var sidePanel: some View {
        ZStack(alignment: .leading) {
            HomeSidePanel(
                sidePanelState: sidePanelState,
                assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel(),
                navigationPath: $viewModel.navigationPath,
                onSelectAssistant: handleAssistantSelection
            )
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
            .background(AppTheme.Colors.secondaryBackground)
            .frame(width: sidebarWidth)
            .offset(x: sidePanelState.isShowing ? 0 : -sidebarWidth)
            .animation(.easeOut, value: sidePanelState.isShowing)
            .environmentObject(apiKeysViewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    func destinationView(for destination: HomeDestination) -> some View {
        Group {
            switch destination {
            case .openai:
                OpenAIChatView(apiKey: apiKeysViewModel.openAIKey)
            case .anthropic:
                AnthropicChatView(apiKey: apiKeysViewModel.anthropicKey)
            case .chat(let assistant):
                ChatView(
                    assistant: assistant,
                    chatViewModel: dependencies.viewModelFactory.makeChatViewViewModel(assistant: assistant),
                    assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel(),
                    tag: "home"
                )
                .id(assistant.id)
            }
        }
        .withCommonNavigationBar()
    }

    var sidePanelGesture: some Gesture {
        DragGesture()
            .onChanged(handleDragChange)
            .onEnded(handleDragEnd)
    }
}

struct HomeDefaultView: View {
    let sidePanelState: SidePanelState
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Cue")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Select an assistant from the menu to start chatting")
                .foregroundColor(.secondary)
        }.padding()
    }
}

// MARK: - Home View Event Handlers
private extension HomeView {
    func handleAssistantSelection(_ assistant: Assistant) {
        viewModel.navigateToDestination(.chat(assistant))
        sidePanelState.hidePanel()
    }

    func handleDragChange(_ gesture: DragGesture.Value) {
        let translation = gesture.translation.width
        if (!sidePanelState.isShowing && translation > 0) ||
           (sidePanelState.isShowing && translation < 0) {
            dragOffset = translation
        }
    }

    func handleDragEnd(_ gesture: DragGesture.Value) {
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

// MARK: - Navigation Bar Modifier
struct CommonNavigationBarModifier: ViewModifier {
    @EnvironmentObject private var sidePanelState: SidePanelState

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        sidePanelState.togglePanel()
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
