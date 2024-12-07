import SwiftUI

struct Sidebar: View {
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    @Binding var selectedAssistant: AssistantStatus?
    @State private var isShowingNewAssistantSheet = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            List(selection: $selectedAssistant) {
                Section("Assistants") {
                    ForEach(assistantsViewModel.sortedAssistants) { assistant in
                        AssistantRow(
                            assistant: assistant,
                            viewModel: assistantsViewModel
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listItemTint(Color.clear)
                        .tag(assistant)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            #if os(macOS)
            .background(
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            )
            #endif
            .accentColor(AppTheme.Colors.lightGray.opacity(0.5))
            .listStyle(.sidebar)
            .onChange(of: selectedAssistant) { _, newValue in
                if newValue == nil && !assistantsViewModel.sortedAssistants.isEmpty {
                    selectedAssistant = assistantsViewModel.sortedAssistants[0]
                }
            }

            Spacer()
            SettingsMenu(
                onOpenAIChat: handleOpenAIChat,
                onOpenSettings: handleOpenSettings
            )
        }
        .background(Color.clear)
        .navigationTitle("Cue")
        .toolbar {
            ToolbarItem {
                NewAssistantButton(action: { isShowingNewAssistantSheet = true })
            }
        }
        .sheet(isPresented: $isShowingNewAssistantSheet) {
            NewAssistantSheet(
                isPresented: $isShowingNewAssistantSheet,
                viewModel: assistantsViewModel
            )
        }
        .onAppear {
            Task {
                await assistantsViewModel.fetchAssistants(tag: "onAppear")
            }
            if selectedAssistant == nil && !assistantsViewModel.sortedAssistants.isEmpty {
                selectedAssistant = assistantsViewModel.sortedAssistants[0]
            }
        }
    }

    private func handleOpenAIChat() {
        #if os(macOS)
        openWindow(id: "openai-chat-window")
        #endif
    }

    private func handleOpenSettings() {
        #if os(macOS)
        openWindow(id: "settings-window")
        #endif
    }
}
