import SwiftUI

public struct ProvidersScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProvidersViewModel
    @State private var selectedProvider: Provider?

    public init(providersViewModel: ProvidersViewModel) {
        _viewModel = StateObject(wrappedValue: providersViewModel)
    }

    public var body: some View {
        CenteredScrollView {
            LazyVStack {
                ForEach(Provider.allCases) { provider in
                    NavigationLink(
                        destination: ProviderDetailView(provider: provider),
                        label: {
                            ProviderRow(
                                provider: provider,
                                viewModel: viewModel
                            )
                            .listRowSeparator(.hidden)
                        }
                    )
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .scrollContentBackground(.hidden)
        }
        .defaultNavigationBar(title: "Providers")
        .alert("Edit Key", isPresented: $viewModel.isAlertPresented) {
            TextField("Enter API Key", text: $viewModel.tempAPIKey)
                .autocorrectionDisabled()

            Button("Cancel", role: .cancel) {
                viewModel.cancelEditing()
            }

            Button("Save") {
                viewModel.saveKey()
            }
        }
        message: {
            EmptyView()
        }
    }
}
