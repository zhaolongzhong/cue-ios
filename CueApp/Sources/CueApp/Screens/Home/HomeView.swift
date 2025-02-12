import SwiftUI

// MARK: - Navigation
enum HomeDestination: Hashable {
    case home
    case cue
    case openai
    case anthropic
    case chat(Assistant)
    case email
}

struct HomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var assistantsViewModel = AssistantsViewModel()
    @StateObject private var sidePanelState = SidePanelState()
    @State private var dragOffset: CGFloat = 0

    // Side panel configuration constants
    private let sidebarWidth: CGFloat = 300
    private let edgeWidth: CGFloat = 20
    private let dragThreshold: CGFloat = 50
    private let animationDuration: Double = 0.3
    private let springStiffness: Double = 300
    private let springDamping: Double = 30

    var body: some View {
        ZStack {
            mainContent
                .disabled(sidePanelState.isShowing)
            overlayLayer
            sidePanel
                .gesture(sidePanelDragGesture)
        }
        .modifier(LeftEdgeGesture(
            edgeWidth: edgeWidth,
            onDragChange: handleEdgeDragChange,
            onDragEnd: handleEdgeDragEnd
        ))
        .background(AppTheme.Colors.secondaryBackground.opacity(0.2))
        .onAppear {
            Task {
                await assistantsViewModel.fetchAssistants()
            }
        }
        .onChange(of: appStateViewModel.state.currentUser) { _, user in
            if user != nil {
                Task {
                    await homeViewModel.initialize()
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $coordinator.showLiveChat) {
            RealtimeChatScreen(
                viewModelFactory: dependencies.viewModelFactory.makeRealtimeChatViewModel,
                apiKey: apiKeysProviderViewModel.openAIKey
            )
        }
        #endif

    }
}

// MARK: - Home View Components
private extension HomeView {
    var mainContent: some View {
        NavigationStack(path: $homeViewModel.navigationPath) {
                Group {
                    HomeDefaultView(viewModel: homeViewModel, onNewSession: {
                        homeViewModel.navigateToDestination(.email)
                    })
                }
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
            .opacity(calculateOverlayOpacity())
            .animation(.easeInOut(duration: animationDuration), value: dragOffset)
            .animation(.easeInOut(duration: animationDuration), value: sidePanelState.isShowing)
            .ignoresSafeArea()
            .allowsHitTesting(sidePanelState.isShowing)
            .onTapGesture {
                withAnimation(.easeInOut(duration: animationDuration)) {
                    #if os(iOS)
                    HapticManager.shared.impact(style: .light)
                    #endif
                    sidePanelState.hidePanel()
                }
            }
    }

    private func calculateOverlayOpacity() -> Double {
        if sidePanelState.isShowing {
            // When panel is showing, calculate opacity based on drag offset
            return 0.3 * (1 + dragOffset / sidebarWidth)
        } else {
            // When panel is closed/opening, calculate opacity based on drag progress
            return 0.3 * (dragOffset / sidebarWidth)
        }
    }

    var sidePanel: some View {
        ZStack(alignment: .leading) {
            HomeSidePanel(
                sidePanelState: sidePanelState,
                assistantsViewModel: assistantsViewModel,
                navigationPath: $homeViewModel.navigationPath,
                onSelectAssistant: handleAssistantSelection
            )
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) }
            .background(AppTheme.Colors.secondaryBackground)
            .frame(width: sidebarWidth)
            .offset(x: sidePanelState.isShowing ? dragOffset : -sidebarWidth + dragOffset)
            .animation(
                .interpolatingSpring(
                    stiffness: springStiffness,
                    damping: springDamping
                ),
                value: sidePanelState.isShowing || dragOffset != 0
            )
            .environmentObject(apiKeysProviderViewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    func destinationView(for destination: HomeDestination) -> some View {
        Group {
            switch destination {
            case .home:
                HomeDefaultView(viewModel: homeViewModel, onNewSession: {
                    homeViewModel.navigateToDestination(.email)
                })
            case .cue:
                CueChatView()
            case .openai:
                OpenAIChatView(apiKey: apiKeysProviderViewModel.openAIKey)
            case .anthropic:
                AnthropicChatView(apiKey: apiKeysProviderViewModel.anthropicKey)
            case .chat(let assistant):
                ChatView(
                    assistant: assistant,
                    chatViewModel: dependencies.viewModelFactory.makeChatViewViewModel(assistant: assistant),
                    assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel(),
                    tag: "home"
                )
                .id(assistant.id)
            case .email:
                #if os(iOS)
                EmailScreen(apiKey: apiKeysProviderViewModel.openAIKey, onClose: {
                    homeViewModel.navigateToDestination(.home)
                })
                #endif
            }
        }
        .withCommonNavigationBar()
    }
}

// MARK: - Home View Event Handlers
private extension HomeView {
    func handleAssistantSelection(_ assistant: Assistant?) {
        if let assistant = assistant {
            homeViewModel.navigateToDestination(.chat(assistant))
        } else {
            homeViewModel.navigateToDestination(.home)
        }

        sidePanelState.hidePanel()
    }

    func handleEdgeDragChange(_ gesture: DragGesture.Value) {
        guard !sidePanelState.isShowing else { return }
        // Only handle edge drag when panel is closed
        dragOffset = max(0, min(sidebarWidth, gesture.translation.width))
    }

    func handleEdgeDragEnd(_ gesture: DragGesture.Value) {
        if !sidePanelState.isShowing {
            let translation = gesture.translation.width
            let velocity = gesture.predictedEndTranslation.width - gesture.translation.width

            withAnimation(.interpolatingSpring(
                stiffness: springStiffness,
                damping: springDamping
            )) {
                if translation > dragThreshold || velocity > 500 {
                    sidePanelState.showPanel()
                } else {
                    sidePanelState.hidePanel()
                }
                dragOffset = 0
            }
        }
    }

    // Gesture for handling panel closing
    var sidePanelDragGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                guard sidePanelState.isShowing else { return }
                // Allow dragging to left (negative values) when panel is open
                dragOffset = min(0, gesture.translation.width)
            }
            .onEnded { gesture in
                guard sidePanelState.isShowing else { return }
                let translation = gesture.translation.width
                let velocity = gesture.predictedEndTranslation.width - gesture.translation.width

                withAnimation(.interpolatingSpring(
                    stiffness: springStiffness,
                    damping: springDamping
                )) {
                    if -translation > dragThreshold || velocity < -500 {
                        sidePanelState.hidePanel()
                    } else {
                        sidePanelState.showPanel()
                    }
                    dragOffset = 0
                }
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
                        HapticManager.shared.impact(style: .light)
                    } label: {
                        Image("menu")
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

struct LeftEdgeGesture: ViewModifier {
    let edgeWidth: CGFloat
    let onDragChange: (DragGesture.Value) -> Void
    let onDragEnd: (DragGesture.Value) -> Void

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture()
                .onChanged { value in
                    // Only process gesture if it started from the left edge
                    if value.startLocation.x <= edgeWidth {
                        onDragChange(value)
                    }
                }
                .onEnded { value in
                    // Only process end if it started from the left edge
                    if value.startLocation.x <= edgeWidth {
                        onDragEnd(value)
                    }
                }
        )
    }
}
