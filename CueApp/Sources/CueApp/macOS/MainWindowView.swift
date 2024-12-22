import SwiftUI
import CueOpenAI

public struct MainWindowView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @StateObject private var apiKeysViewModel: APIKeysViewModel
    @State private var selectedAssistant: Assistant?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var lastStatusUpdate: Date = Date()

    #if os(macOS)
    @State private var windowDelegate: WindowDelegate?
    #endif

    init(viewModelFactory: @escaping () -> AssistantsViewModel, apiKeysViewModelFactory: @escaping () -> APIKeysViewModel) {
        self._assistantsViewModel = StateObject(wrappedValue: viewModelFactory())
        self._apiKeysViewModel = StateObject(wrappedValue: apiKeysViewModelFactory())
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(
                assistantsViewModel: assistantsViewModel,
                selectedAssistant: $selectedAssistant
            )
            .id("sidebar-\(lastStatusUpdate.timeIntervalSince1970)")
        } detail: {
            NavigationStack {
                DetailContent(
                    assistantsViewModel: assistantsViewModel,
                    selectedAssistant: selectedAssistant ?? assistantsViewModel.assistants.first
                )
            }
        }
        .environmentObject(apiKeysViewModel)
        .onChange(of: appStateViewModel.state) { _, state in
            if let _ = state.currentUser?.id {
                Task {
                    await assistantsViewModel.connect()
                }
            }
        }
        .onChange(of: assistantsViewModel.assistants) { _, newValue in
            if selectedAssistant == nil && !newValue.isEmpty {
                selectedAssistant = newValue.first
            }
        }
        .onReceive(assistantsViewModel.$clientStatuses) { _ in
            AppLog.log.debug("Client status updated, forcing view refresh")
            lastStatusUpdate = Date()
        }
        .onAppear {
            if selectedAssistant == nil && !assistantsViewModel.assistants.isEmpty {
                selectedAssistant = assistantsViewModel.assistants.first
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
