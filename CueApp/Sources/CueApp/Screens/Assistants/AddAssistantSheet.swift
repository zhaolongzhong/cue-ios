import SwiftUI

struct AddAssistantSheet: View {
    @ObservedObject var viewModel: AssistantsViewModel
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
            .navigationTitle("New Assistant")
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
                    Button("Create") {
                        Task {
                            _ = await viewModel.createAssistant(name: name)
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
            Text("New Assistant")
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

                Button("Create") {
                    Task {
                        _ = await viewModel.createAssistant(name: name)
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
    }
}
