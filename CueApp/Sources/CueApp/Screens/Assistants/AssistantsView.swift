import SwiftUI
import Combine

struct AssistantsView: View {
    @ObservedObject private var viewModel: AssistantsViewModel
    @State private var isShowingNameDialog = false
    @State private var newAssistantName = ""

    init(viewModel: AssistantsViewModel) {
        self.viewModel = viewModel
    }

    public var sortedAssistants: [AssistantStatus] {
        viewModel.assistantStatuses.sorted { first, second in
            if first.assistant.metadata?.isPrimary == true {
                return true
            }
            if second.assistant.metadata?.isPrimary == true {
                return false
            }
            return first.isOnline && !second.isOnline
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                List(sortedAssistants) { assistant in
                    NavigationLink(
                        destination: ChatView(
                            assistant: assistant,
                            webSocketManagerStore: viewModel.webSocketManagerStore,
                            assistantsViewModel: viewModel
                        )
                    ) {
                        AssistantRowView(
                            assistant: assistant,
                            status: viewModel.getClientStatus(for: assistant)
                        )
                    }
                    .contextMenu {
                        if assistant.assistant.metadata?.isPrimary != true {
                            AssistantContextMenu(
                                assistant: assistant,
                                viewModel: viewModel
                            )
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if assistant.assistant.metadata?.isPrimary != true {
                            Button(role: .destructive) {
                                viewModel.assistantToDelete = assistant
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .refreshable {
                    viewModel.refreshAssistants()
                }
                .overlay {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
                .navigationTitle("Assistants")
                #if os(iOS)
                .listStyle(InsetGroupedListStyle())
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                #endif
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            isShowingNameDialog = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            #if os(iOS)
            .navigationViewStyle(.stack)
            #endif
            .deleteConfirmation(
                isPresented: Binding(
                    get: { viewModel.assistantToDelete != nil },
                    set: { if !$0 { viewModel.assistantToDelete = nil } }
                ),
                assistant: viewModel.assistantToDelete,
                onDelete: { assistant in
                    Task {
                        await viewModel.deleteAssistant(assistant)
                        viewModel.assistantToDelete = nil
                    }
                }
            )

            if isShowingNameDialog {
                TextFieldAlert(
                    isPresented: $isShowingNameDialog,
                    text: $newAssistantName,
                    title: "New Assistant",
                    message: "Enter a name for the new assistant"
                ) { name in
                    Task {
                        await viewModel.createAssistant(name: name)
                    }
                }
            }
        }
    }
}
