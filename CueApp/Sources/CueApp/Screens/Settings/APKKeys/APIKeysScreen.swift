import SwiftUI

struct APIKeysView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = APIKeysViewModel()
    @State private var selectedKey: APIKey?

    var body: some View {
        List {
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
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
        .defaultNavigationBar(title: "Assistants API Keys")
        .toolbar {
            ToolbarItem(placement: .automatic) {
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

struct APIKeyRow: View {
    let key: APIKey
    @State private var showCopiedFeedback = false
    @State private var showUpdateSheet = false
    @State private var showDeleteAlert = false
    @Binding var selectedKey: APIKey?
    let onDelete: (APIKey) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(key.name)
                    .font(.headline)
                Spacer()
                #if os(iOS)
                Menu {
                    Button("Update", action: {
                        selectedKey = key
                    })
                    Button("Delete", role: .destructive, action: {
                        showDeleteAlert = true
                    })
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
                #else
                HStack(spacing: 8) {
                    Button {
                        selectedKey = key
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Update API Key")

                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete API Key")
                }
                #endif
            }

            HStack(spacing: 4) {
                Text(maskKey(key.secret))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                CopyButton(
                    content: key.secret,
                    isVisible: true
                )
            }

            if let lastUsed = key.lastUsedAt {
                Text("Last used: \(formatDate(lastUsed))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Never used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.all, 8)
        .background(AppTheme.Colors.secondaryBackground)
        .cornerRadius(8)
        .contextMenu {
            Button("Update") {
                selectedKey = key
            }
            Button("Delete", role: .destructive) {
                showDeleteAlert = true
            }
        }
        .alert("Delete API Key",
               isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete(key)
            }
        } message: {
            Text("Are you sure you want to delete this API key? This action cannot be undone.")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func maskKey(_ key: String) -> String {
        // The key format is "sk-...DgIA"
        if key.count > 8 {
            let prefix = String(key.prefix(4))
            let suffix = String(key.suffix(4))
            return "\(prefix)...\(suffix)"
        }
        return key
    }
}
