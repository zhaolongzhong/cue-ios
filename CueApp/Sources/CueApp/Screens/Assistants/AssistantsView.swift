import SwiftUI
import Combine

struct AssistantActionsHelper: AssistantActions {
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

protocol AssistantActions {
    func onDelete(assistant: Assistant)
    func onDetails(assistant: Assistant)
    @MainActor func onSetPrimary(assistant: Assistant)
    func onChat(assistant: Assistant)
}

struct AssistantsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appStateViewModel: AppStateViewModel
    @StateObject private var assistantsViewModel: AssistantsViewModel
    @State private var isShowingNameDialog = false
    @State private var newAssistantName = ""
    @State private var isShowingDeleteConfirmation = false
    @State private var assistantToDelete: Assistant?
    private var showDeleteAlert: Binding<Bool> {
        Binding(
            get: { assistantToDelete != nil },
            set: { if !$0 { assistantToDelete = nil } }
        )
    }
    @Binding var navigationPath: NavigationPath

    init(viewModelFactory: @escaping () -> AssistantsViewModel, navigationPath: Binding<NavigationPath>) {
        self._assistantsViewModel = StateObject(wrappedValue: viewModelFactory())
        self._navigationPath = navigationPath
    }

    var body: some View {
        AssistantsListView(
            assistantsViewModel: assistantsViewModel,
            actions: AssistantActionsHelper(
                navigationPath: $navigationPath,
                assistantsViewModel: assistantsViewModel,
                setAssistantToDelete: { assistant in
                    assistantToDelete = assistant
                }
            )
        )

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

struct AssistantsListView: View {
    @ObservedObject var assistantsViewModel: AssistantsViewModel
    let actions: AssistantActions?

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(assistantsViewModel.assistants) { assistant in
                    AssistantRowV2(
                        assistant: assistant,
                        status: assistantsViewModel.getClientStatus(for: assistant),
                        actions: actions
                    )
                    .onTapGesture {
                        actions?.onChat(assistant: assistant)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            actions?.onDelete(assistant: assistant)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.orange)
                    }
                    Divider().background(AppTheme.Colors.separator.opacity(0.1))
                        .padding(.vertical, 8)
                        .padding(.leading, 46)
                }
            }
            .padding()
        }
        .refreshable {
            assistantsViewModel.refreshAssistants()
        }
        .overlay {
            if assistantsViewModel.isLoading {
                ProgressView()
            }
        }
    }
}
