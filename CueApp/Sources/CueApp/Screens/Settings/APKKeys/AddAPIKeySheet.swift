import SwiftUI

struct AddAPIKeySheet: View {
    @ObservedObject var viewModel: APIKeysViewModel
    var updateKey: APIKey?
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        #if os(iOS)
        navigationView
        #else
        macOSView
        #endif
    }

    private var navigationView: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
            }
            .navigationTitle(updateKey != nil ? "Update API Key" : "New API Key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(updateKey != nil ? "Update" : "Create") {
                        Task {
                            if let updateKey = updateKey {
                                await viewModel.updateKey(updateKey, name: name)
                            } else {
                                await viewModel.createNewAPIKey(name: name)
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private var macOSView: some View {
        VStack(spacing: 20) {
            Text(updateKey != nil ? "Update API Key" : "New API Key")
                .font(.headline)

            Form {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
            }
            .padding()

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button(updateKey != nil ? "Update" : "Create") {
                    Task {
                        if let updateKey = updateKey {
                            await viewModel.updateKey(updateKey, name: name)
                        } else {
                            await viewModel.createNewAPIKey(name: name)
                        }
                        dismiss()
                    }
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            if let updateKey = updateKey {
                name = updateKey.name
            }
        }
    }
}

struct NewKeyCreatedSheet: View {
    let apiKey: APIKeyPrivate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        navigationView
        #else
        macOSView
        #endif
    }

    private var navigationView: some View {
        NavigationView {
            sharedContent
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }

    private var macOSView: some View {
        VStack {
            sharedContent

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.return)
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
        .frame(width: 500)
    }

    private var sharedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)

            Text("API Key Created")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text(apiKey.secret)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)

                    CopyButton(
                        content: apiKey.secret,
                        isVisible: true
                    )
                }
            }
            .padding(.vertical)
        }
        .padding()
    }
}
