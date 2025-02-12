import SwiftUI
import CueOpenAI
import Dependencies

class SharedNavigationState: ObservableObject {
    @Published var columnVisibility: NavigationSplitViewVisibility = .all
}

public struct MainWindowView: View {
    @StateObject private var sharedNavState = SharedNavigationState()
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var selectionManager = HomeNavigationManager()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var lastStatusUpdate: Date = Date()

    #if os(macOS)
    @State private var windowDelegate: WindowDelegate?
    #endif

    init(viewModelFactory: @escaping () -> AssistantsViewModel) {
        self._assistantsViewModel = StateObject(wrappedValue: viewModelFactory())
    }

    public var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $sharedNavState.columnVisibility) {
                Sidebar(
                    assistantsViewModel: assistantsViewModel,
                    onOpenHome: {
                        selectionManager.selectDetailContent(.home)
                    },
                    onOpenCueChat: {
                        selectionManager.selectDetailContent(.chat)
                    },
                    selectedAssistant: Binding(
                        get: { selectionManager.selectedAssistant },
                        set: {
                            selectionManager.selectDetailContent(.assistant($0))
                        }
                    )
                )
                .navigationSplitViewColumnWidth(min: WindowSize.sidebarMiniWidth, ideal: WindowSize.sidebarIdealWidth, max: WindowSize.sidebarMaxWidth)
                .id("sidebar-\(lastStatusUpdate.timeIntervalSince1970)")
            } detail: {
                if !selectionManager.isEmailViewPresented {
                    NavigationStack {
                        switch selectionManager.currentView {
                        case .home:
                            HomeDefaultView(viewModel: homeViewModel, onNewSession: {
                                selectionManager.selectDetailContent(.email)
                            })
                        case .assistant(let assistant):
                            DetailContent(
                                assistantsViewModel: assistantsViewModel,
                                selectedAssistant: assistant
                            )
                        case .chat:
                            CueChatView()
                        case .email:
                            HomeDefaultView(viewModel: homeViewModel, onNewSession: {
                                selectionManager.selectDetailContent(.email)
                            })
                        }
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)

            #if os(macOS)
            if selectionManager.isEmailViewPresented {
                EmailScreen(
                    apiKey: apiKeysProviderViewModel.openAIKey,
                    sharedNavState: sharedNavState,
                    onClose: {
                        selectionManager.isEmailViewPresented = false
                    }
                )
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
            #endif
        }
        .environmentObject(apiKeysProviderViewModel)
        .onReceive(assistantsViewModel.$clientStatuses) { _ in
            lastStatusUpdate = Date()
        }
        .onChange(of: appStateViewModel.state.currentUser) { _, user in
            if user != nil {
                Task {
                    await homeViewModel.initialize()
                }
            }
        }
        #if os(macOS)
        .overlay(
            WindowAccessor { window in
                guard let window = window else { return }
                loadWindowState(for: window)
                self.windowDelegate = WindowDelegate(saveState: { [weak window] in
                    guard let window = window else { return }
                    saveWindowState(for: window)
                })
                window.delegate = self.windowDelegate
            }
        )
        #endif
    }
}
