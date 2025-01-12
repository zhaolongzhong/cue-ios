import SwiftUI
import Dependencies

@MainActor
final class SidePanelState: ObservableObject {
    @Published var isShowing = false
    @Published var isShowingNewAssistant = false

    private let selectionManager: AssistantSelectionManager

    // Forward the selectedAssistant from the manager
    var selectedAssistant: Assistant? {
        get { selectionManager.selectedAssistant }
        set { selectionManager.selectAssistant(newValue) }
    }

    init(selectionManager: AssistantSelectionManager = AssistantSelectionManager()) {
        self.selectionManager = selectionManager
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

    // Forward selection methods to the manager
    func selectAssistant(_ assistant: Assistant?) {
        selectionManager.selectAssistant(assistant)
    }

    func restoreSelection(from assistants: [Assistant]) {
        selectionManager.restoreSelection(from: assistants)
    }
}

struct HomeSidePanel: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var apiKeyProviderViewModel: APIKeysProviderViewModel
    @ObservedObject var sidePanelState: SidePanelState
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    @Binding var navigationPath: NavigationPath
    let onSelectAssistant: (Assistant) -> Void
    @State private var assistantForDetails: Assistant?
    @State private var assistantToDelete: Assistant?

    init(
        sidePanelState: SidePanelState,
        assistantsViewModel: AssistantsViewModel,
        navigationPath: Binding<NavigationPath>,
        onSelectAssistant: @escaping (Assistant) -> Void
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
            VStack(spacing: 16) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if !apiKeyProviderViewModel.openAIKey.isEmpty || !apiKeyProviderViewModel.anthropicKey.isEmpty {
                            providersSection
                        }
                        assistantsSection
                    }
                }

                settingsRow
            }
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Cue")
                        .font(.title2)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        sidePanelState.isShowingNewAssistant = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            #endif
            .padding(.horizontal, 16)
            .background(AppTheme.Colors.secondaryBackground)
            .onAppear {
                Task {
                    await assistantsViewModel.fetchAssistants()
                    if sidePanelState.selectedAssistant == nil {
                        sidePanelState.restoreSelection(from: assistantsViewModel.assistants)
                    }
                    if let assistant = sidePanelState.selectedAssistant {
                        onSelectAssistant(assistant)
                    }
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

    private var providersSection: some View {
        Section(header: providersHeader) {
            if !apiKeyProviderViewModel.openAIKey.isEmpty {
                openAIRow
            }
            if !apiKeyProviderViewModel.anthropicKey.isEmpty {
                anthropicRow
            }
        }
        #if os(iOS)
        .listSectionSpacing(.compact)
        #endif
    }

    private var providersHeader: some View {
        HStack {
            Text("Providers")
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.secondary)
        }
    }

    private var assistantsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Assistants")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Divider()
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
