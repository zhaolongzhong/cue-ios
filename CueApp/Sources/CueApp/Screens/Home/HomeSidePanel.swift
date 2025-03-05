import SwiftUI
import Dependencies

@MainActor
final class SidePanelState: ObservableObject {
    @Published var isShowing = false
    @Published var isShowingNewAssistant = false

    private let navigationManager: HomeNavigationManager

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
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var providersViewModel: ProvidersViewModel
    @Dependency(\.authRepository) var authRepository
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @ObservedObject private var sidePanelState: SidePanelState
    @ObservedObject private var assistantsViewModel: AssistantsViewModel
    @Binding private var navigationPath: NavigationPath
    private let onSelectAssistant: (Assistant?) -> Void
    @State private var assistantForDetails: Assistant?
    @State private var assistantToDelete: Assistant?

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
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Button {
                            onSelectAssistant(nil)
                        } label: {
                            Text("~")
                                .font(.title2)
                        }
                    }
                }
                #endif
                .onAppear {
                    Task {
                        await assistantsViewModel.fetchAssistants()
                    }
                }
        }
        .sheet(item: $assistantForDetails) { assistant in
            AssistantDetailView(
                assistant: assistant,
                assistantsViewModel: self.assistantsViewModel,
                onUpdate: nil
            )
            .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $sidePanelState.isShowingNewAssistant) {
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
                VStack(spacing: 16) {
                    if featureFlags.enableCue {
                        cueRow
                        Divider()
                            .opacity(0.5)
                    }
                    emailRow
                    if featureFlags.enableProviders {
                        if !providersViewModel.enabledProviders.isEmpty {
                            Divider()
                                .opacity(0.5)
                            providersSection
                        }
                    }
                    if featureFlags.enableAssistants {
                        assistantsSection
                    }
                }
                .padding(.horizontal, 8)
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

    private func navigate(to route: HomeDestination) {
        navigationPath.append(route)
        sidePanelState.hidePanel()
    }

    private var providersSection: some View {
        Section(header: providersHeader) {
            if providersViewModel.enabledProviders.isEmpty {
                emptyProvidersStateView
            } else {
                ForEach(providersViewModel.enabledProviders, id: \.self) { provider in
                    switch provider {
                    case .openai where providersViewModel.isProviderEnabled(.openai) && featureFlags.enableOpenAI:
                        ProviderSidebarRow(provider: provider) {
                            navigate(to: .openai())
                        }
                    case .anthropic where providersViewModel.isProviderEnabled(.anthropic) && featureFlags.enableAnthropic:
                        ProviderSidebarRow(provider: provider) {
                            navigate(to: .anthropic())
                        }
                    case .gemini where providersViewModel.isProviderEnabled(.gemini) && featureFlags.enableGemini:
                        ProviderSidebarRow(provider: provider) {
                            navigate(to: .gemini())
                        }
                    default:
                        AnyView(EmptyView())
                    }
                }
            }
        }
        #if os(iOS)
        .listSectionSpacing(.compact)
        #endif
    }

    private var emptyProvidersStateView: some View {
        Text("No providers configured")
            .foregroundColor(.secondary)
            .font(.caption)
    }

    private var providersHeader: some View {
        SectionHeader(
            title: "Providers",
            trailingIcon: .system("plus"),
            trailingAction: {
                coordinator.showProvidersSheet()
            }
        )
    }

    private var assistantsSection: some View {
        Section(header: assistantsSectionHeader) {
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
                .onTapGesture {
                    sidePanelState.selectAssistant(assistant)
                    onSelectAssistant(assistant)
                }
            }
        }
        #if os(iOS)
        .listSectionSpacing(.compact)
        #endif
    }

    private var cueRow: some View {
        SidebarRowButton(
            title: "Cue",
            icon: .custom("~"),
            action: {
                navigate(to: .cue())
            }
        )
    }

    private var emailRow: some View {
        SidebarRowButton(
            title: "Email",
            icon: .system("envelope"),
            action: {
                navigate(to: HomeDestination.email)
            }
        )
    }

    private var assistantsSectionHeader: some View {
        SectionHeader(
            title: "Assistants",
            trailingIcon: .system("plus"),
            trailingAction: { sidePanelState.isShowingNewAssistant = true }
        )
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
