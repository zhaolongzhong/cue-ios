import SwiftUI
import Combine

public struct NewAssistantButton: View {
    let action: () -> Void

    public var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
        }
        .frame(width: 38, height: 38)
    }
}

public struct NewAssistantSheet: View {
    @Binding var isPresented: Bool
    let viewModel: AssistantsViewModel
    @State private var name = ""

    public var body: some View {
        Form {
            TextField("Assistant Name", text: $name)
                .textFieldStyle(.roundedBorder)
        }
        .padding()
        .frame(width: 300)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        _ = await viewModel.createAssistant(name: name)
                        isPresented = false
                    }
                }
                .disabled(name.isEmpty)
            }
        }
    }
}

public struct AssistantContextMenu: View {
    let assistant: Assistant
    @ObservedObject var viewModel: AssistantsViewModel

    public var body: some View {
        Group {
            Button {
                Task {
                    _ = await viewModel.setPrimaryAssistant(id: assistant.id)
                }
            } label: {
                Label("Set as Primary", systemImage: "star.fill")
            }

            Button(role: .destructive) {
                viewModel.assistantToDelete = assistant
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func deleteConfirmation(
        isPresented: Binding<Bool>,
        assistant: Assistant?,
        onDelete: @escaping (Assistant) -> Void
    ) -> some View {
        confirmationDialog(
            "Delete Assistant",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            if let assistant = assistant {
                Button("Delete", role: .destructive) {
                    onDelete(assistant)
                }
                Button("Cancel", role: .cancel) {
                    isPresented.wrappedValue = false
                }
            }
        } message: {
            Text("Are you sure you want to delete this assistant? This action cannot be undone.")
        }
    }
}
