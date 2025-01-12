import SwiftUI
import CueOpenAI
import Dependencies

public struct MainWindowView: View {
    @Dependency(\.webSocketService) public var webSocketService
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
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
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(
                assistantsViewModel: assistantsViewModel,
                selectedAssistant: Binding(
                    get: { selectionManager.selectedAssistant },
                    set: { selectionManager.selectAssistant($0) }
                )
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 300, max: 400)
            .id("sidebar-\(lastStatusUpdate.timeIntervalSince1970)")
        } detail: {
            NavigationStack {
                DetailContent(
                    assistantsViewModel: assistantsViewModel,
                    selectedAssistant: selectionManager.selectedAssistant ?? assistantsViewModel.assistants.first
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(apiKeysProviderViewModel)
        .onChange(of: assistantsViewModel.assistants) { _, newValue in
            if selectionManager.selectedAssistant == nil {
                selectionManager.restoreSelection(from: newValue)
            }
        }
        .onReceive(assistantsViewModel.$clientStatuses) { _ in
            lastStatusUpdate = Date()
        }
        .onAppear {
            Task {
                await webSocketService.connect()
            }
            if selectionManager.selectedAssistant == nil {
                selectionManager.restoreSelection(from: assistantsViewModel.assistants)
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
