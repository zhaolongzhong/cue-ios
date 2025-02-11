import SwiftUI
import CueOpenAI
import Dependencies

enum DetailViewType {
    case home
    case assistant(Assistant)
    case chat
}

public struct MainWindowView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @StateObject private var homeViewModel: HomeViewModel
    @State private var selectedAssistant: Assistant?
    @StateObject private var selectionManager = AssistantSelectionManager()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var lastStatusUpdate: Date = Date()
    private let userId: String

    #if os(macOS)
    @State private var windowDelegate: WindowDelegate?
    #endif

    init(userId: String, viewModelFactory: @escaping () -> AssistantsViewModel) {
        self.userId = userId
        self._assistantsViewModel = StateObject(wrappedValue: viewModelFactory())
        let homeViewModel = HomeViewModel(userId: userId)
        _homeViewModel = StateObject(wrappedValue: homeViewModel)
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(
                assistantsViewModel: assistantsViewModel,
                onOpenHome: {
                    selectionManager.selectAssistant(nil)
                },
                selectedAssistant: Binding(
                    get: { selectionManager.selectedAssistant },
                    set: { selectionManager.selectAssistant($0) }
                )
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 400)
            .id("sidebar-\(lastStatusUpdate.timeIntervalSince1970)")
        } detail: {
            NavigationStack {
                switch selectionManager.currentView {
                case .home:
                    HomeDefaultView(viewModel: homeViewModel, onNewSession: {
                        selectionManager.showChat()
                    })
                case .assistant(let assistant):
                    DetailContent(
                        assistantsViewModel: assistantsViewModel,
                        selectedAssistant: assistant
                    )
                case .chat:
                    CueChatView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(apiKeysProviderViewModel)
        .onReceive(assistantsViewModel.$clientStatuses) { _ in
            lastStatusUpdate = Date()
        }
        .onAppear {
            Task {
                await homeViewModel.initialize()
            }
        }
        #if os(macOS)
        .overlay(
            WindowAccessor { window in
                guard let window = window else { return }
                // Load window state
                loadWindowState(for: window)

                // Assign delegate to handle window events
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
