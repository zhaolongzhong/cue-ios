import SwiftUI

struct APIKeyRowView: View {
    let keyType: APIKeyType
    @ObservedObject var viewModel: APIKeysViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(keyType.displayName)
                    .font(.headline)
                Spacer()
                if !viewModel.getAPIKey(for: keyType).isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 16) {
                if viewModel.getAPIKey(for: keyType).isEmpty {
                    Text("Not configured")
                        .foregroundColor(.secondary)
                } else {
                    Text("••••••••" + viewModel.getAPIKey(for: keyType).suffix(4))
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                HStack(spacing: 4) {
                    if !viewModel.getAPIKey(for: keyType).isEmpty {
                        Button(role: .destructive) {
                            viewModel.deleteKey(keyType)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(minWidth: 44)
                        }
                        .buttonStyle(.borderless)
                    }
                    Button {
                        viewModel.startEditing(keyType)
                    } label: {
                        Text(viewModel.getAPIKey(for: keyType).isEmpty ? "Add" : "Edit")
                            .frame(minWidth: 44)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
