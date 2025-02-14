import SwiftUI
import Dependencies

@MainActor
final class SidePanelState: ObservableObject {
    @Published var isShowing = false
    @Published var isShowingNewAssistant = false

    private let navigationManager: HomeNavigationManager

    var selectedAssistant: Assistant? {
        get { navigationManager.selectedAssistant }
        set { navigationManager.selectDetailContent(.assistant(newValue)) }
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
        navigationManager.selectDetailContent(.assistant(assistant))
    }
}

struct HomeSidePanel: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var apiKeyProviderViewModel: APIKeysProviderViewModel
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
                            Text("Cue")
                                .font(.title2)
                        }
                    }
                }
                #endif
                .background(AppTheme.Colors.secondaryBackground)
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
        VStack(spacing: 16) {
            ScrollView {
                LazyVStack {
                    if featureFlags.enableCueChat {
                        cueRow
                        Divider()
                    }
                    emailRow
                    if featureFlags.enableThirdPartyProvider {
                        if !apiKeyProviderViewModel.openAIKey.isEmpty
                            || !apiKeyProviderViewModel.anthropicKey.isEmpty
                            || !apiKeyProviderViewModel.geminiKey.isEmpty {
                            Divider()
                            providersSection
                        }
                    }
                    if featureFlags.enableAssistants {
                        assistantsSection
                    }
                }
                .padding(.horizontal, 8)
            }
            settingsRow
        }
    }

    private var providersSection: some View {
        Section(header: providersHeader) {
            if !apiKeyProviderViewModel.openAIKey.isEmpty && featureFlags.enableOpenAIChat {
                openAIRow
            }
            if !apiKeyProviderViewModel.anthropicKey.isEmpty && featureFlags.enableAnthropicChat {
                anthropicRow
            }
            if !apiKeyProviderViewModel.geminiKey.isEmpty && featureFlags.enableGeminiChat {
                geminiRow
            }
        }
        #if os(iOS)
        .listSectionSpacing(.compact)
        #endif
    }

    private var providersHeader: some View {
        HStack {
            Text("Third Party Providers")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.secondary)
        }
    }

    private var assistantsSection: some View {
        Section(header: assistantsRow) {
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
                sidePanelState.togglePanel()
                navigationPath.append(HomeDestination.cue)
            }
        )
    }

    private var emailRow: some View {
        SidebarRowButton(
            title: "Email",
            icon: .system("envelope"),
            action: {
                sidePanelState.togglePanel()
                navigationPath.append(HomeDestination.email)
            }
        )
    }

    private var assistantsRow: some View {
        SectionHeader(
            title: "Assistants",
            trailingIcon: .system("plus"),
            trailingAction: { sidePanelState.isShowingNewAssistant = true }
        )
    }

    private var openAIRow: some View {
        IconRow(
            title: "OpenAI",
            action: {
                navigationPath.append(HomeDestination.openai)
                sidePanelState.hidePanel()
            },
            iconName: "openai"
        )
    }

    private var anthropicRow: some View {
        IconRow(
            title: "Anthropic",
            action: {
                navigationPath.append(HomeDestination.anthropic)
                sidePanelState.hidePanel()
            },
            iconName: "anthropic"
        )
    }

    private var geminiRow: some View {
        IconRow(
            title: "Gemini",
            action: {
                navigationPath.append(HomeDestination.gemini)
                sidePanelState.hidePanel()
            },
            iconName: "sparkle",
            isSystemImage: true
        )
    }

    private var settingsRow: some View {
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
