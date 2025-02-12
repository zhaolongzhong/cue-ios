import SwiftUI
import CueOpenAI
import Dependencies

enum DetailViewType {
    case home
    case assistant(Assistant)
    case chat
    case email
}

public struct MainWindowView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var selectionManager = AssistantSelectionManager()
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
            // Main content with sidebar
            NavigationSplitView(columnVisibility: $columnVisibility) {
                Sidebar(
                    assistantsViewModel: assistantsViewModel,
                    onOpenHome: {
                        selectionManager.selectAssistant(nil)
                    },
                    selectedAssistant: Binding(
                        get: { selectionManager.selectedAssistant },
                        set: {
                            selectionManager.selectAssistant($0)
                        }
                    )
                )
                .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 400)
                .id("sidebar-\(lastStatusUpdate.timeIntervalSince1970)")
            } detail: {
                NavigationStack {
                    switch selectionManager.currentView {
                    case .home:
                        HomeDefaultView(viewModel: homeViewModel, onNewSession: {
                            selectionManager.showEmail()
                        })
                    case .assistant(let assistant):
                        DetailContent(
                            assistantsViewModel: assistantsViewModel,
                            selectedAssistant: assistant
                        )
                    case .chat:
                        CueChatView()
                    case .email:
                        Color.clear // Placeholder as email view will be shown as full-screen overlay
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)

            if selectionManager.isEmailViewPresented {
                EmailSummarizationView(selectionManager: selectionManager)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
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
