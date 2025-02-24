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
    @EnvironmentObject private var providersViewModel: ProvidersViewModel
    @ObservedObject private var assistantsViewModel: AssistantsViewModel
    @Binding private var selectedAssistant: Assistant?
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
                assistantsViewModel: self.assistantsViewModel,
                onUpdate: nil
            )
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
                    if featureFlags.enableCue {
                        cueRow
                    }
                    emailRow
                    if featureFlags.enableProviders {
                        if !providersViewModel.enabledProviders.isEmpty {
                            Divider()
                                .opacity(0.5)
                            providersSection
                        }
                    }
                }
                .padding(.horizontal, 16)
                if featureFlags.enableAssistants {
                    assistantsSection
                }
            }
        }
    }

    private var cueRow: some View {
        SidebarRowButton(
            title: "Cue",
            icon: .custom("~"),
            action: {
                homeNavigationManager.navigateTo(.cue)
            }
        )
    }

    private var emailRow: some View {
        SidebarRowButton(
            title: "Email",
            icon: .system("envelope"),
            action: {
                homeNavigationManager.navigateTo(.home)
            }
        )
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
                homeNavigationManager.navigateTo(.openai)
                #if os(macOS)
                openWindow(id: WindowId.providersManagement.rawValue)
                #endif
            }
        )
    }

    private var providersSection: some View {
        VStack(spacing: 0) {
            providersHeader

            if providersViewModel.enabledProviders.isEmpty {
                emptyProvidersStateView
            } else {
                ForEach(providersViewModel.enabledProviders, id: \.self) { provider in
                    switch provider {
                    case .openai where providersViewModel.isProviderEnabled(.openai) && featureFlags.enableOpenAI:
                        ProviderSidebarRow(provider: provider) {
                            homeNavigationManager.navigateTo(.openai)
                        }
                    case .anthropic where providersViewModel.isProviderEnabled(.anthropic) && featureFlags.enableAnthropic:
                        ProviderSidebarRow(provider: provider) {
                            homeNavigationManager.navigateTo(.anthropic)
                        }
                    case .gemini where providersViewModel.isProviderEnabled(.gemini) && featureFlags.enableGemini:
                        ProviderSidebarRow(provider: provider) {
                            homeNavigationManager.navigateTo(.gemini)
                        }
                    case .local where featureFlags.enableLocal:
                        ProviderSidebarRow(provider: provider) {
                            homeNavigationManager.navigateTo(.local)
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

    private var assistantsSection: some View {
        VStack {
            assistantsSectionHeader
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

    private var assistantsSectionHeader: some View {
        SectionHeader(
            title: "Assistants",
            trailingIcon: .system("plus"),
            trailingAction: { isShowingNewAssistantSheet = true }
        )
    }
}

struct ProviderSidebarRow: View {
    let provider: Provider
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack {
                ProviderAvatar(
                    iconName: provider.iconName,
                    isSystemImage: provider.isSystemIcon
                )

                Text(provider.displayName)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
