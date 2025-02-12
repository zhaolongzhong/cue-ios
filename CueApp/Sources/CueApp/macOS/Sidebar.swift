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
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var apiKeyProviderViewModel: APIKeysProviderViewModel
    @ObservedObject private var assistantsViewModel: AssistantsViewModel
    @Binding private var selectedAssistant: Assistant?
    @State private var isShowingNewAssistantSheet = false
    @State private var assistantForDetails: Assistant?
    @State private var assistantToDelete: Assistant?
    private let onOpenHome: () -> Void

    private var showDeleteAlert: Binding<Bool> {
        Binding(
            get: { assistantToDelete != nil },
            set: { if !$0 { assistantToDelete = nil } }
        )
    }

    init(assistantsViewModel: AssistantsViewModel, onOpenHome: @escaping () -> Void, selectedAssistant: Binding<Assistant?>) {
        self.assistantsViewModel = assistantsViewModel
        self.onOpenHome = onOpenHome
        self._selectedAssistant = selectedAssistant
    }

    var body: some View {
        VStack {
            Button(action: onOpenHome) {
                Text("Cue")
                    .font(.title)
            }
            .buttonStyle(.plain)
            ScrollView {
                LazyVStack {
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
                        .onTapGesture { selectedAssistant = assistant }
                        .tag(assistant)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            Spacer()
            SettingsMenu(
                currentUser: authRepository.currentUser,
                onOpenAIChat: handleOpenAIChat,
                onAnthropicChat: handleAnthropicChat,
                onOpenSettings: handleOpenSettings
            )
            .padding(.all, 4)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .strokeBorder(AppTheme.Colors.separator, lineWidth: 0.5))
            .padding(.all, 8)
        }
        #if os(macOS)
        .background(
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        #endif
        .navigationTitle("Cue")
        .toolbar {
            ToolbarItem {
                NewAssistantButton(action: { isShowingNewAssistantSheet = true })
            }
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

    private func handleOpenAIChat() {
        #if os(macOS)
        openWindow(id: "openai-chat-window")
        #endif
    }

    private func handleAnthropicChat() {
        #if os(macOS)
        openWindow(id: "anthropic-chat-window")
        #endif
    }

    private func handleOpenSettings() {
        #if os(macOS)
        openWindow(id: "settings-window")
        #endif
    }
}
