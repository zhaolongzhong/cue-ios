import SwiftUI

struct Sidebar: View {
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    @Binding var selectedAssistant: AssistantStatus?
    @State private var isShowingNewAssistantSheet = false

    var body: some View {
        VStack {
            List(selection: $selectedAssistant) {
                Section("Assistants") {
                    ForEach(assistantsViewModel.assistantStatuses.sorted { first, second in
                        if first.assistant.metadata?.isPrimary == true {
                            return true
                        }
                        if second.assistant.metadata?.isPrimary == true {
                            return false
                        }
                        return first.isOnline && !second.isOnline
                    }) { assistant in
                        AssistantRow(
                            assistant: assistant,
                            viewModel: assistantsViewModel
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listItemTint(Color.clear)
                        .tag(assistant)
                    }
                }
            }

            .accentColor(AppTheme.Colors.lightGray)
            .listStyle(.sidebar)
            .listRowInsets(EdgeInsets())
            .scrollContentBackground(.hidden)

            HStack {
                UserAvatarMenu()
                Spacer()
            }
            .padding(.all, 4)
        }
        .background(AppTheme.Colors.secondaryBackground)
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
    }
}
