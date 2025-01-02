import SwiftUI

struct APIKeysProviderView: View {
    @StateObject private var viewModel: APIKeysProviderViewModel
    @Environment(\.dismiss) private var dismiss

    init(apiKeysProviderViewModel: APIKeysProviderViewModel) {
        _viewModel = StateObject(wrappedValue: apiKeysProviderViewModel)
    }

    var body: some View {
        List {
            ForEach(APIKeyType.allCases) { keyType in
                APIKeyRowView(
                    keyType: keyType,
                    viewModel: viewModel
                )
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Provider API Keys")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            alertOverlay
        }
    }

    private var alertOverlay: some View {
        Group {
            if viewModel.isAlertPresented,
               let keyType = viewModel.editingKeyType {
                TextFieldAlert(
                    isPresented: Binding(
                        get: { viewModel.isAlertPresented },
                        set: { if !$0 { viewModel.cancelEditing() } }
                    ),
                    text: Binding(
                        get: { viewModel.tempAPIKey },
                        set: { viewModel.tempAPIKey = $0 }
                    ),
                    title: "Edit \(keyType.displayName) API Key",
                    message: ""
                ) { _ in
                    viewModel.saveKey()
                }
            }
        }
    }
}
