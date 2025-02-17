import SwiftUI
import CueOpenAI
import Dependencies

public struct MainWindowView: View {
    // MARK: - Environment & State Objects
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var apiKeysProviderViewModel: APIKeysProviderViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var emailScreenViewModel: EmailScreenViewModel
    @StateObject private var mainNavigationManager = HomeNavigationManager()

    // MARK: - State Properties
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var lastStatusUpdate: Date = Date()
    @State private var selectedEmailCategory: EmailCategory? = .newsletters

    #if os(macOS)
    @State private var windowDelegate: WindowDelegate?
    #endif

    // MARK: - Initialization

    public init(viewModelFactory: @escaping () -> AssistantsViewModel) {
        _assistantsViewModel = StateObject(wrappedValue: viewModelFactory())
        _emailScreenViewModel = StateObject(wrappedValue: EmailScreenViewModel())
    }

    // MARK: - Body

    public var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(apiKeysProviderViewModel)
        .onReceive(assistantsViewModel.$clientStatuses) { _ in
            lastStatusUpdate = Date()
        }
        .onChange(of: appStateViewModel.state.currentUser) { _, user in
            handleUserChange(user)
        }
        #if os(macOS)
        .overlay(windowStateHandler)
        #endif
    }

    // MARK: - View Components

    @ViewBuilder
    private var sidebarContent: some View {
        Group {
            if mainNavigationManager.isEmailViewPresented {
                emailSidebarView
            } else {
                standardSidebarView
            }
        }
        .navigationSplitViewColumnWidth(
            min: WindowSize.sidebarMiniWidth,
            ideal: WindowSize.sidebarIdealWidth,
            max: WindowSize.sidebarMaxWidth
        )
        .id("sidebar-\(lastStatusUpdate.timeIntervalSince1970)")
    }

    @ViewBuilder
    private var emailSidebarView: some View {
        EmailCategoryView(
            selectedCategory: $selectedEmailCategory,
            emailSummaries: emailScreenViewModel.emailSummaries,
            isLoading: emailScreenViewModel.processingState.isLoading
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                homeButton
            }
        }
    }

    private var homeButton: some View {
        Button {
            mainNavigationManager.isEmailViewPresented = false
        } label: {
            Image(systemName: "house")
        }
    }

    private var standardSidebarView: some View {
        Sidebar(
            assistantsViewModel: assistantsViewModel,
            onOpenHome: handleOpenHome,
            onOpenCueChat: handleOpenCueChat,
            selectedAssistant: assistantBinding
        )
    }

    @ViewBuilder
    private var detailContent: some View {
        if mainNavigationManager.isEmailViewPresented {
            #if os(macOS)
            EmailScreen(
                emailScreenViewModel: emailScreenViewModel,
                selectedEmailCategory: $selectedEmailCategory
            )
            #endif
        } else {
            mainNavigationContent
        }
    }

    private var mainNavigationContent: some View {
        NavigationStack {
            switch mainNavigationManager.currentView {
            case .home, .email:
                HomeDefaultView(
                    viewModel: homeViewModel,
                    onNewSession: handleNewSession
                )
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

    #if os(macOS)
    private var windowStateHandler: some View {
        WindowAccessor { window in
            guard let window = window else { return }
            handleWindowSetup(window)
        }
    }
    #endif

    // MARK: - Computed Properties

    private var assistantBinding: Binding<Assistant?> {
        Binding(
            get: { mainNavigationManager.selectedAssistant },
            set: { mainNavigationManager.selectDetailContent(.assistant($0)) }
        )
    }

    // MARK: - Action Handlers

    private func handleOpenHome() {
        mainNavigationManager.selectDetailContent(.home)
    }

    private func handleOpenCueChat() {
        mainNavigationManager.selectDetailContent(.chat)
    }

    private func handleNewSession() {
        mainNavigationManager.selectDetailContent(.email)
    }

    private func handleUserChange(_ user: User?) {
        if user != nil {
            Task {
                await homeViewModel.initialize()
            }
        }
    }

    #if os(macOS)
    private func handleWindowSetup(_ window: NSWindow) {
        loadWindowState(for: window)
        windowDelegate = WindowDelegate(saveState: { [weak window] in
            guard let window = window else { return }
            saveWindowState(for: window)
        })
        window.delegate = windowDelegate
    }
    #endif
}
