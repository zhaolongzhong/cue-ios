import SwiftUI

struct ProviderRow: View {
    let provider: Provider
    @ObservedObject var viewModel: ProvidersViewModel
    @State private var showDeleteAlert = false

    private var isConfigured: Bool {
        !viewModel.getAPIKey(for: provider).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                provider.iconView
                Text(provider.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
                if isConfigured {
                    Menu {
                        Button("Delete", role: .destructive) {
                            showDeleteAlert = true
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
            }

            HStack(spacing: 16) {
                if isConfigured {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0, green: 0.8, blue: 0.2))
                        Text("Configured")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(Color(red: 0, green: 0.8, blue: 0.2))
                    }
                    .transition(.opacity)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                        Text("Not configured")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }
                Spacer()
            }
        }
        .padding(.all, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isConfigured
                      ? AppTheme.Colors.separator.opacity(0.5)
                      : AppTheme.Colors.separator.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isConfigured ? AppTheme.Colors.separator : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .cornerRadius(10)
        .animation(.easeInOut(duration: 0.2), value: isConfigured)
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
