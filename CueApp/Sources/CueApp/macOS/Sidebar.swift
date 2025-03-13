import SwiftUI
import Dependencies

struct SidebarAssistantActions: AssistantActions {
    var assistantsViewModel: AssistantsViewModel
    var setAssistantToDelete: (Assistant) -> Void
    var onDetailsPressed: (Assistant) -> Void

    func onDelete(assistant: Assistant) {
        setAssistantToDelete(assistant)
    }

    func onDetails(assistant: Assistant) {
        onDetailsPressed(assistant)
    }

    func onSetPrimary(assistant: Assistant) {
        assistantsViewModel.setPrimaryAssistant(id: assistant.id)
    }

    func onChat(assistant: Assistant) {

    }
}

struct Sidebar: View {
    @Dependency(\.authRepository) var authRepository
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var providersViewModel: ProvidersViewModel
    @ObservedObject private var assistantsViewModel: AssistantsViewModel
    @Binding private var selectedAssistant: Assistant?
    @State private var selectedProvider: Provider?
    @State private var isShowingNewAssistantSheet = false
    @State private var assistantForDetails: Assistant?
    @State private var assistantToDelete: Assistant?
    private let homeNavigationManager: HomeNavigationManager
    @Environment(\.openWindow) private var openWindow

    private var showDeleteAlert: Binding<Bool> {
        Binding(
            get: { assistantToDelete != nil },
            set: { if !$0 { assistantToDelete = nil } }
        )
    }

    init(
        assistantsViewModel: AssistantsViewModel,
        homeNavigationManager: HomeNavigationManager,
        selectedAssistant: Binding<Assistant?>
    ) {
        self.assistantsViewModel = assistantsViewModel
        self.homeNavigationManager = homeNavigationManager
        self._selectedAssistant = selectedAssistant
    }

    var body: some View {
        VStack {
            contentList
            Spacer()
            SettingsMenu(currentUser: authRepository.currentUser)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
        #if os(macOS)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        #endif
        .navigationTitle("Cue")
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
        .sheet(item: $assistantForDetails) { assistant in
            AssistantDetailView(
                assistant: assistant,
                onUpdate: nil
            )
            .sheetWidth(.medium)
            .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $isShowingNewAssistantSheet) {
            AddAssistantSheet(viewModel: assistantsViewModel)
        }
        .onAppear {
            Task {
                await assistantsViewModel.fetchAssistants()
            }
        }
    }

    private var contentList: some View {
        ScrollView {
            LazyVStack {
                Group {
                    if featureFlags.enableAssistants {
                        AssistantsRow(
                            onTap: { selectedProvider = nil }
                        )
                    }
                    if featureFlags.enableEmail {
                        SidebarEmailRow(
                            onTap: { homeNavigationManager.navigateTo(.email) }
                        )
                    }
                    if featureFlags.enableProviders {
                        if !providersViewModel.enabledProviders.isEmpty {
                            ProvidersSection(
                                selectedProvider: $selectedProvider,
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
        }
    }

    private var conversationsSection: some View {
        Group {
            if let selectedProvider = selectedProvider {
                ConversationsView(
                    viewModel: dependencies.viewModelFactory.makeConversationViewModel(provider: selectedProvider),
                    provider: selectedProvider
                ) { conversationId in
                    homeNavigationManager.navigateToConversation(provider: selectedProvider, conversationId: conversationId)
                }
            }
        }
    }

    private var assistantsSection: some View {
        VStack {
            SectionHeader(
                title: "Assistants",
                trailingIcon: .system("plus"),
                trailingAction: { isShowingNewAssistantSheet = true }
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
                        .fill(selectedAssistant == assistant ? AppTheme.Colors.separator.opacity(0.5) : Color.clear)
                )
                .padding(.horizontal, 8)
                .onTapGesture {
                    selectedAssistant = assistant
                }
                .tag(assistant)
            }
            .scrollContentBackground(.hidden)
        }
    }
}
