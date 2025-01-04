import SwiftUI

struct APIKeysProviderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: APIKeysProviderViewModel

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
        .defaultNavigationBar(title: "Provider API Keys")
        .inputAlert(
            title: "Edit Key",
            text: Binding(
                get: { viewModel.tempAPIKey },
                set: { viewModel.tempAPIKey = $0 }
            ),
            isPresented: Binding(
                get: { viewModel.isAlertPresented },
                set: { if !$0 { viewModel.cancelEditing() } }
            ),

            onSave: { _ in
                viewModel.saveKey()
            }
        )
    }
}
