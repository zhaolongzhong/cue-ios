import SwiftUI

public struct ProvidersScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProvidersViewModel

    public init(providersViewModel: ProvidersViewModel) {
        _viewModel = StateObject(wrappedValue: providersViewModel)
    }

    public var body: some View {
        ScrollView {
            HStack {
                Spacer()
                LazyVStack {
                    ForEach(Provider.allCases) { provider in
                        ProviderRow(
                            provider: provider,
                            viewModel: viewModel
                        )
                        .listRowSeparator(.hidden)
                    }
                }
                .padding()
                .scrollContentBackground(.hidden)
                .frame(maxWidth: 600)
                Spacer()
            }
        }
        .defaultNavigationBar(title: "Providers")
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
