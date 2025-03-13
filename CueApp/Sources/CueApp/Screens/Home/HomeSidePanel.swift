import SwiftUI
import Dependencies

@MainActor
final class SidePanelState: ObservableObject {
    @Published var isShowing = false
    @Published var isShowingNewAssistantSheet = false

    let navigationManager: HomeNavigationManager

    var selectedAssistant: Assistant? {
        get { navigationManager.selectedAssistant }
        set {
            if let assistant = newValue {
                navigationManager.navigateTo(.chat(assistant))
            } else {
                navigationManager.navigateTo(.home)
            }
        }
    }

    init(navigationManager: HomeNavigationManager = HomeNavigationManager()) {
        self.navigationManager = navigationManager
    }

    func togglePanel() {
        withAnimation(.easeOut) {
            isShowing.toggle()
        }
    }

    func hidePanel() {
        withAnimation(.easeOut) {
            isShowing = false
        }
    }

    func showPanel() {
        isShowing = true
    }

    func selectAssistant(_ assistant: Assistant?) {
        if let assistant = assistant {
            navigationManager.navigateTo(.chat(assistant))
        } else {
            navigationManager.navigateTo(.home)
        }
    }
}

struct HomeSidePanel: View {
    @Dependency(\.authRepository) var authRepository
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var providersViewModel: ProvidersViewModel
    @ObservedObject private var sidePanelState: SidePanelState
    @ObservedObject private var assistantsViewModel: AssistantsViewModel
    @Binding private var navigationPath: NavigationPath
    private let onSelectAssistant: (Assistant?) -> Void
    @State private var lastSelectedProvider: Provider?
    @State private var selectedProvider: Provider?
    @State private var assistantForDetails: Assistant?
    @State private var assistantToDelete: Assistant?

    var navigationManager: HomeNavigationManager {
        sidePanelState.navigationManager
    }

    init(
        sidePanelState: SidePanelState,
        assistantsViewModel: AssistantsViewModel,
        navigationPath: Binding<NavigationPath>,
        onSelectAssistant: @escaping (Assistant?) -> Void
    ) {
        self.sidePanelState = sidePanelState
        self.assistantsViewModel = assistantsViewModel
        self._navigationPath = navigationPath
        self.onSelectAssistant = onSelectAssistant
    }

    private var showDeleteAlert: Binding<Bool> {
        Binding(
            get: { assistantToDelete != nil },
            set: { if !$0 { assistantToDelete = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            contentList
                .onAppear {
                    Task {
                        await assistantsViewModel.fetchAssistants()
                    }
                }
        }
        .sheet(item: $assistantForDetails) { assistant in
            AssistantDetailView(
                assistant: assistant,
                onUpdate: nil
            )
            .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $sidePanelState.isShowingNewAssistantSheet) {
            AddAssistantSheet(viewModel: assistantsViewModel)
        }
        .alert("Delete Assistant", isPresented: showDeleteAlert, presenting: assistantToDelete) { assistant in
            Button("Delete", role: .destructive) {
                Task {
                    await assistantsViewModel.deleteAssistant(assistant)
                    assistantToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                assistantToDelete = nil
            }
        } message: { assistant in
            Text("Are you sure you want to delete \"\(assistant.name)\"?")
        }
    }

    private var contentList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    Group {
                        if featureFlags.enableAssistants {
                            AssistantsRow(
                                onTap: {
                                    self.lastSelectedProvider = self.selectedProvider
                                    self.selectedProvider = nil
                                }
                            )
                        }

                        if featureFlags.enableEmail {
                            SidebarEmailRow(
                                onTap: { navigate(to: HomeDestination.email) }
                            )
                        }

                        if featureFlags.enableProviders {
                            if !providersViewModel.enabledProviders.isEmpty {
                                ProvidersSection(
                                    selectedProvider: Binding(
                                        get: { self.selectedProvider },
                                        set: {
                                            self.lastSelectedProvider = self.selectedProvider
                                            self.selectedProvider = $0
                                        }
                                    ),
                                    providersViewModel: providersViewModel,
                                    featureFlags: featureFlags
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    if selectedProvider != nil {
                        conversationsSection
                    } else {
                        if featureFlags.enableAssistants {
                            Divider()
                                .opacity(0.2)
                                .padding(.horizontal, 16)
                            assistantsSection
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .background(AppTheme.Colors.secondaryBackground)

            VStack {
                Divider()
                    .opacity(0.5)
                settingsRow
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
            }
            .background(.ultraThickMaterial)
        }
    }

    private func navigate(to route: HomeDestination, hidePanel: Bool = true) {
        navigationPath.append(route)
        if hidePanel {
            sidePanelState.hidePanel()
        }
    }

    private var conversationsSection: some View {
        Group {
            if let selectedProvider = selectedProvider {
                ConversationsView(
                    viewModel: dependencies.viewModelFactory.makeConversationViewModel(provider: selectedProvider),
                    provider: selectedProvider
                ) { conversationId in
                    let hidePanel: Bool = lastSelectedProvider != nil
                    lastSelectedProvider = selectedProvider
                    switch selectedProvider {
                    case .openai:
                        navigate(to: .openai(conversationId), hidePanel: hidePanel)
                    case .anthropic:
                        navigate(to: .anthropic(conversationId), hidePanel: hidePanel)
                    case .gemini:
                        navigate(to: .gemini(conversationId), hidePanel: hidePanel)
                    case .cue:
                        navigate(to: .cue(conversationId), hidePanel: hidePanel)
                    case .local:
                        navigate(to: .local(conversationId), hidePanel: hidePanel)
                    }
                }
            }
        }
    }

    private var assistantsSection: some View {
        VStack {
            SectionHeader(
                title: "Assistants",
                trailingIcon: .system("plus"),
                trailingAction: { sidePanelState.isShowingNewAssistantSheet = true }
            )
            .padding(.horizontal, 16)
            ForEach(assistantsViewModel.assistants) { assistant in
                AssistantRow(
                    assistant: assistant,
                    status: assistantsViewModel.getClientStatus(for: assistant),
                    actions: SidebarAssistantActions(
                        assistantsViewModel: assistantsViewModel,
                        setAssistantToDelete: { assistant in
                            assistantToDelete = assistant
                        },
                        onDetailsPressed: { _ in
                            assistantForDetails = assistant
                        }
                    )
                )
                .padding(.horizontal, 8)
                .withHoverEffect()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(navigationManager.selectedAssistant == assistant ? AppTheme.Colors.separator.opacity(0.5) : Color.clear)
                )
                .padding(.horizontal, 8)
                .onTapGesture {
//                    selectedAssistant = assistant
                    sidePanelState.selectAssistant(assistant)
                    onSelectAssistant(assistant)
                }
                .tag(assistant)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var settingsRow: some View {
        Group {
            if let user = authRepository.currentUser, !user.displayName.isEmpty {
                Button {
                    coordinator.showSettingsSheet()
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        UserAvatar(user: user, size: 32)
                        Text(user.displayName)
                        Spacer()
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                IconRow(
                    title: "Settings",
                    action: {
                        coordinator.showSettingsSheet()
                    },
                    iconName: "gearshape",
                    isSystemImage: true
                )
            }
        }
    }
}
