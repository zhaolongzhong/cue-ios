import SwiftUI

struct Sidebar: View {
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    @Binding var selectedAssistant: Assistant?
    @State private var isShowingNewAssistantSheet = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            List(selection: $selectedAssistant) {
                ForEach(assistantsViewModel.assistants) { assistant in
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
            .scrollContentBackground(.hidden)
            #if os(macOS)
            .background(
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                    .ignoresSafeArea()
            )
            #endif
            .accentColor(AppTheme.Colors.secondaryBackground.opacity(0.5))
            .listStyle(.sidebar)
            .onChange(of: selectedAssistant) { _, _ in
                self.onSelectedAssistantUpdate()
            }

            Spacer()
            SettingsMenu(
                onOpenAIChat: handleOpenAIChat,
                onAnthropicChat: handleAnthropicChat,
                onOpenSettings: handleOpenSettings
            )
            .padding(.all, 4)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .strokeBorder(AppTheme.Colors.separator, lineWidth: 0.5))
            .padding(.all, 8)
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
            self.onSelectedAssistantUpdate()
        }
    }

    private func onSelectedAssistantUpdate() {
        if selectedAssistant == nil && !assistantsViewModel.assistants.isEmpty {
            selectedAssistant = assistantsViewModel.assistants[0]
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
