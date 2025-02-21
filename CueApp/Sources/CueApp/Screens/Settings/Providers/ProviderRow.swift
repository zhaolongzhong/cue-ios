import SwiftUI

struct ProviderRow: View {
    let provider: Provider
    @ObservedObject var viewModel: ProvidersViewModel
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                provider.iconView
                Text(provider.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                Menu {
                    Button(viewModel.getAPIKey(for: provider).isEmpty ? "Add" : "Edit") {
                        viewModel.startEditing(provider)
                    }
                    if !viewModel.getAPIKey(for: provider).isEmpty {
                        Button("Delete", role: .destructive) {
                            showDeleteAlert = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .menuIndicator(.hidden)
                .menuStyle(.borderlessButton)
                .frame(width: 24)
                .fixedSize()
            }

            HStack(spacing: 16) {
                if viewModel.getAPIKey(for: provider).isEmpty {
                    Text("Not configured")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    SecretView(secret: viewModel.getAPIKey(for: provider))
                }
                Spacer()
            }
        }
        .padding(.all, 8)
        #if os(macOS)
        .background(AppTheme.Colors.separator.opacity(0.5))
        #else
        .background(AppTheme.Colors.secondaryBackground.opacity(0.2))
        #endif
        .cornerRadius(8)
        .alert("Delete API Key",
               isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteKey(provider)
            }
        } message: {
            Text("Are you sure you want to delete this API key?")
        }
    }
}
