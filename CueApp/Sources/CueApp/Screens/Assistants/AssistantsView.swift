import SwiftUI
import Combine

struct AssistantsView: View {
    @StateObject private var viewModel: AssistantsViewModel
    @EnvironmentObject private var authService: AuthService
    private let webSocketStore: WebSocketManagerStore

    init(webSocketStore: WebSocketManagerStore) {
        self.webSocketStore = webSocketStore
        _viewModel = StateObject(wrappedValue: AssistantsViewModel(webSocketStore: webSocketStore))
    }

    var body: some View {
        NavigationStack {
            List(viewModel.assistantStatuses) { assistant in
                NavigationLink(
                    destination: ChatView(
                        assistant: assistant,
                        status: viewModel.getClientStatus(for: assistant),
                        webSocketStore: self.webSocketStore,
                        assistantsViewModel: viewModel
                    )
                ) {
                    AssistantRowView(
                        assistant: assistant,
                        status: viewModel.getClientStatus(for: assistant)
                    )
                }
                .contextMenu {
                    Button(role: .destructive, action: {
                        Task {
                            await viewModel.deleteAssistant(assistant)
                        }
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive, action: {
                        Task {
                            await viewModel.deleteAssistant(assistant)
                        }
                    }) {
                        Label("Delete", systemImage: "trash")
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
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
        }
        .navigationViewStyle(.stack)
    }
}
