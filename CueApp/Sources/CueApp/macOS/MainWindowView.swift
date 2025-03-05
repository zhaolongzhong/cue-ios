import SwiftUI
import CueOpenAI
import Dependencies

public struct MainWindowView: View {
    // MARK: - Environment & State Objects
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @EnvironmentObject private var providersViewModel: ProvidersViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var emailScreenViewModel: EmailScreenViewModel
    @StateObject private var mainNavigationManager = HomeNavigationManager()

    // MARK: - State Properties
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedEmailCategory: EmailCategory? = .newsletters

    #if os(macOS)
    @State private var windowDelegate: WindowDelegate?
    #endif
    @Environment(\.colorScheme) private var colorScheme

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
        .environmentObject(providersViewModel)
        .onChange(of: appStateViewModel.state.currentUser) { oldValue, newValue in
            if let newUser = newValue, newUser != oldValue {
                handleUserChange(newUser)
            }
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
            homeNavigationManager: mainNavigationManager,
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
                .background(colorScheme == .dark ? Color(.lightGray).opacity(0.1) : AppTheme.Colors.background)
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
            case .chat(let assistant):
                AssistantChatView(
                    assistantChatViewModel: dependencies.viewModelFactory.makeAssistantChatViewModel(assistant: assistant),
                    assistantsViewModel: assistantsViewModel
                )
                .id(assistant.id)
            case .anthropic:
                ChatViewFactory.createChatView(provider: .anthropic, appDependencies: dependencies)
            case .gemini:
                ChatViewFactory.createChatView(provider: .gemini, appDependencies: dependencies)
            case .openai:
                ChatViewFactory.createChatView(provider: .openai, appDependencies: dependencies)
            case .cue:
                ChatViewFactory.createChatView(provider: .cue, appDependencies: dependencies)
            case .local:
                ChatViewFactory.createChatView(provider: .local, appDependencies: dependencies)
            case .providers:
                EmptyView()
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
            set: {
                if let assitant = $0 {
                    mainNavigationManager.navigateTo(.chat(assitant))
                } else {
                    mainNavigationManager.navigateTo(.home)
                }
            }
        )
    }

    // MARK: - Action Handlers

    private func handleNewSession() {
        mainNavigationManager.navigateTo(.email)
    }

    private func handleUserChange(_ user: User) {
        Task {
            await homeViewModel.initialize()
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
