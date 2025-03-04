import SwiftUI
import Combine

enum AppDestination: Hashable {
    case chat(Assistant)
    case details(Assistant)
}

struct NavigationAssistantActions: AssistantActions {
    var navigationPath: Binding<NavigationPath>
    var assistantsViewModel: AssistantsViewModel
    var setAssistantToDelete: (Assistant) -> Void

    func onDelete(assistant: Assistant) {
        setAssistantToDelete(assistant)
    }

    func onDetails(assistant: Assistant) {
        navigationPath.wrappedValue.append(AppDestination.details(assistant))
    }

    func onSetPrimary(assistant: Assistant) {
        assistantsViewModel.setPrimaryAssistant(id: assistant.id)
    }

    func onChat(assistant: Assistant) {
        navigationPath.wrappedValue.append(AppDestination.chat(assistant))
    }
}

struct AssistantsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @State private var isShowingNameDialog = false
    @State private var newAssistantName = ""
    @State private var navigationPath = NavigationPath()
    @State private var isShowingDeleteConfirmation = false
    @State private var assistantToDelete: Assistant?

    private var showDeleteAlert: Binding<Bool> {
        Binding(
            get: { assistantToDelete != nil },
            set: { if !$0 { assistantToDelete = nil } }
        )
    }

    init(viewModelFactory: @escaping () -> AssistantsViewModel) {
        self._assistantsViewModel = StateObject(wrappedValue: viewModelFactory())
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            AssistantsListView(
                assistantsViewModel: assistantsViewModel,
                actions: NavigationAssistantActions(
                    navigationPath: $navigationPath,
                    assistantsViewModel: assistantsViewModel,
                    setAssistantToDelete: { assistant in
                        assistantToDelete = assistant
                    }
                )
            )
            .defaultNavigationBar(showCustomBackButton: false, title: "Assistants")
            #if os(iOS)
            .listStyle(InsetGroupedListStyle())

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
                case .chat(let assistant):
                    AssistantChatView(
                        assistantChatViewModel: dependencies.viewModelFactory.makeAssistantChatViewModel(assistant: assistant),
                        assistantsViewModel: dependencies.viewModelFactory.makeAssistantsViewModel()
                    )
                case .details(let assistant):
                    AssistantDetailView(
                        assistant: assistant,
                        assistantsViewModel: assistantsViewModel,
                        onUpdate: nil
                    )
                }
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
        .overlay {
            if isShowingNameDialog {
                TextFieldAlert(
                    isPresented: $isShowingNameDialog,
                    text: $newAssistantName,
                    title: "New Assistant",
                    message: "Enter a name for the new assistant"
                ) { name in
                    Task {
                        await assistantsViewModel.createAssistant(name: name)
                    }
                }
            }
        }
        .onAppear {
            Task {
                if appStateViewModel.state.isAuthenticated {
                    await assistantsViewModel.fetchAssistants()
                }
            }
        }
    }
}
