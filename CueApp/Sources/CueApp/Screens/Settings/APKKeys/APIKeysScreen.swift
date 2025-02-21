import SwiftUI

struct APIKeysView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = APIKeysViewModel()
    @State private var selectedKey: APIKey?

    var body: some View {
        ScrollView {
            HStack {
                Spacer()
                LazyVStack {
                    if viewModel.isLoading && viewModel.apiKeys.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden)
                    }

                    errorMessage

                    ForEach(viewModel.apiKeys) { key in
                        APIKeyRow(
                            key: key,
                            selectedKey: $selectedKey,
                            onDelete: { key in
                                Task {
                                    await viewModel.deleteKey(key)
                                }
                            }
                        )
                        .listRowSeparator(.hidden)
                        .task {
                            await viewModel.loadMoreIfNeeded(currentItem: key)
                        }
                    }

                    if viewModel.isLoading && !viewModel.apiKeys.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden)
                    }
                }
                .padding()
                .scrollContentBackground(.hidden)
                .frame(maxWidth: 600)
                Spacer()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .defaultNavigationBar(title: "API Keys")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Button {
                    viewModel.isShowingAddKey = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await viewModel.fetch()
        }
        .sheet(isPresented: $viewModel.isShowingAddKey) {
            AddAPIKeySheet(viewModel: viewModel, updateKey: nil)
        }
        .sheet(item: $viewModel.newKeyCreated) { apiKey in
            NewKeyCreatedSheet(apiKey: apiKey)
        }
        .sheet(item: $selectedKey) { key in
            AddAPIKeySheet(viewModel: viewModel, updateKey: key)
        }
    }

    private var errorMessage: some View {
        Group {
            if let error = viewModel.error {
                VStack {
                    Text("Error loading API keys")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Try Again") {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                    .padding(.top)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            }

        }
    }
}
