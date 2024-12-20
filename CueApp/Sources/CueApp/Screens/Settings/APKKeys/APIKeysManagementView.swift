import SwiftUI

struct APIKeysManagementView: View {
    @StateObject private var viewModel: APIKeysViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModelFactory: @escaping () -> APIKeysViewModel) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
    }

    var body: some View {
        #if os(iOS)
        APIKeysList(viewModel: viewModel)
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                alertOverlay
            }
        #else
        VStack(spacing: 0) {
            HStack {
                Text("API Keys")
                    .font(.title)
                    .padding()
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .padding()
            }

            APIKeysList(viewModel: viewModel)
        }
        .frame(width: 500, height: 400)
        .alert(
            viewModel.editingKeyType?.displayName ?? "",
            isPresented: Binding(
                get: { viewModel.isAlertPresented },
                set: { if !$0 { viewModel.cancelEditing() } }
            )
        ) {
            TextField(
                "API Key",
                text: Binding(
                    get: { viewModel.tempAPIKey },
                    set: { viewModel.tempAPIKey = $0 }
                )
            )
            Button("Save") {
                viewModel.saveKey()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelEditing()
            }
        }
        #endif
    }

    #if os(iOS)
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
    #endif
}

// MARK: - API Keys List
private struct APIKeysList: View {
    @ObservedObject var viewModel: APIKeysViewModel

    var body: some View {
        List {
            ForEach(APIKeyType.allCases) { keyType in
                APIKeyRowView(
                    keyType: keyType,
                    viewModel: viewModel
                )
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        .background(Color.clear)
        #endif
    }
}
