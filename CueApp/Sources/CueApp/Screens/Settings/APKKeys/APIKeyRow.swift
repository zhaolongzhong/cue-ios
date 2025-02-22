import SwiftUI

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
                Menu {
                    Button("Update", action: {
                        selectedKey = key
                    })
                    Button("Delete", role: .destructive, action: {
                        showDeleteAlert = true
                    })
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

            HStack(spacing: 4) {
                SecretView(secret: key.secret)
                CopyButton(
                    content: key.secret,
                    isVisible: true
                )
            }

            if let lastUsed = key.lastUsedAt {
                Text("Last used: \(formatDate(lastUsed))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                Text("Never used")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.all, 8)
        #if os(macOS)
        .background(AppTheme.Colors.separator.opacity(0.5))
        #else
        .background(AppTheme.Colors.secondaryBackground.opacity(0.2))
        #endif
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
            Text("Are you sure you want to delete this API key?")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
