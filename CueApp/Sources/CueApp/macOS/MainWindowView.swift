import SwiftUI

public struct MainWindowView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var assistantsViewModel: AssistantsViewModel
    @State private var selectedAssistant: AssistantStatus?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    #if os(macOS)
    @State private var windowDelegate: WindowDelegate?
    #endif

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Sidebar(
                assistantsViewModel: assistantsViewModel,
                selectedAssistant: $selectedAssistant
            )
        } detail: {
            NavigationStack {
                DetailContent(
                    assistantsViewModel: assistantsViewModel,
                    selectedAssistant: selectedAssistant ?? assistantsViewModel.sortedAssistants.first
                )
            }
        }
        .onChange(of: appStateViewModel.state.currentUser) { _, newUser in
            if let userId = newUser?.id {
                assistantsViewModel.webSocketManagerStore.initialize(for: userId)
            }
        }
        .onChange(of: assistantsViewModel.assistantStatuses) { _, _ in
            if selectedAssistant == nil && !assistantsViewModel.sortedAssistants.isEmpty {
                selectedAssistant = assistantsViewModel.sortedAssistants.first
            }
        }
        .onAppear {
            if selectedAssistant == nil && !assistantsViewModel.sortedAssistants.isEmpty {
                selectedAssistant = assistantsViewModel.sortedAssistants.first
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

#if os(macOS)
extension MainWindowView {
    // MARK: - Window State Persistence

    private func saveWindowState(for window: NSWindow) {

        let frame = window.frame
        UserDefaults.standard.set(frame.origin.x, forKey: "windowOriginX")
        UserDefaults.standard.set(frame.origin.y, forKey: "windowOriginY")
        UserDefaults.standard.set(frame.size.width, forKey: "windowWidth")
        UserDefaults.standard.set(frame.size.height, forKey: "windowHeight")
    }

    private func loadWindowState(for window: NSWindow) {
        let originX = UserDefaults.standard.double(forKey: "windowOriginX")
        let originY = UserDefaults.standard.double(forKey: "windowOriginY")
        let width = UserDefaults.standard.double(forKey: "windowWidth")
        let height = UserDefaults.standard.double(forKey: "windowHeight")

        if width > 0 && height > 0 && width > height {
            let newFrame = NSRect(x: originX, y: originY, width: width, height: height)
            window.setFrame(newFrame, display: true)
        } else {
            // Set default size if no saved state
            window.setContentSize(NSSize(width: 800, height: 600))
            window.center()
        }
    }

    // MARK: - Window Delegate

    private class WindowDelegate: NSObject, NSWindowDelegate {
        var saveState: () -> Void

        init(saveState: @escaping () -> Void) {
            self.saveState = saveState
        }

        func windowDidMove(_ notification: Notification) {
            saveState()
        }

        func windowDidResize(_ notification: Notification) {
            saveState()
        }
    }
}
#endif
