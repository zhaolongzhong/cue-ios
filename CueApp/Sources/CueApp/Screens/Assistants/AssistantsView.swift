import SwiftUI
import Combine

enum AppDestination: Hashable {
    case chat(AssistantStatus)
}

struct AssistantsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @StateObject private var viewModel: AssistantsViewModel
    @State private var isShowingNameDialog = false
    @State private var newAssistantName = ""
    @State private var navigationPath = NavigationPath()

    init(viewModelFactory: @escaping () -> AssistantsViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModelFactory())
        AppLog.log.debug("AssistantsView init()")
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List(viewModel.sortedAssistants) { assistant in
                NavigationLink(
                    value: AppDestination.chat(assistant)
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
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        isShowingNameDialog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            #endif
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .chat(let assistantStatus):
                    ChatView(
                        assistant: assistantStatus,
                        chatViewModel: dependencies.viewModelFactory.makeChatViewViewModel(assistant: assistantStatus),
                        assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel(),
                        tag: "assistants"
                    )
                }
            }
        }
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
        .overlay {
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
        .onAppear {
            AppLog.log.debug("AssistantsView onAppear isAuthenticated: \(appStateViewModel.state.isAuthenticated)")
            Task {
                if appStateViewModel.state.isAuthenticated {
                    await viewModel.fetchAssistants(tag: "onAppear")
                }

//                try await OpenAIClient.example()
            }
        }
    }
}
