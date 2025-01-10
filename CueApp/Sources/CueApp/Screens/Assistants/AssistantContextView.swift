import SwiftUI

struct AssistantContextView: View {
    @ObservedObject var viewModel: AssistantDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            #if os(macOS)
            MacHeader(
                title: "Assistant Context",
                onDismiss: { dismiss() }
            )
            #endif
            
            ScrollView {
                VStack(spacing: 20) {
                    contextSection(
                        title: "Project Context",
                        content: viewModel.assistant.metadata?.context ?? "No project context available",
                        onEdit: { viewModel.showingProjectContextEdit = true }
                    )
                    
                    contextSection(
                        title: "System Context",
                        content: viewModel.assistant.metadata?.system ?? "No system context available",
                        onEdit: { viewModel.showingSystemContextEdit = true }
                    )
                }
                .padding()
            }
        }
        .sheet(isPresented: $viewModel.showingProjectContextEdit) {
            TextFieldEditorSheet(
                title: "Edit Project Context",
                text: Binding(
                    get: { viewModel.assistant.metadata?.context ?? "" },
                    set: { viewModel.projectContext = $0 }
                )
            ) { newValue in
                Task {
                    await viewModel.updateMetadata(context: newValue)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSystemContextEdit) {
            TextFieldEditorSheet(
                title: "Edit System Context",
                text: Binding(
                    get: { viewModel.assistant.metadata?.system ?? "" },
                    set: { viewModel.systemContext = $0 }
                )
            ) { newValue in
                Task {
                    await viewModel.updateMetadata(system: newValue)
                }
            }
        }
    }
    
    private func contextSection(title: String, content: String, onEdit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.accentColor)
                }
            }
            
            Text(content)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

#Preview {
    AssistantContextView(viewModel: AssistantDetailViewModel(
        assistant: Assistant(
            id: "preview",
            name: "Preview Assistant",
            createdAt: Date(),
            updatedAt: Date(),
            metadata: AssistantMetadata(
                isPrimary: true,
                model: "gpt-4",
                instruction: nil,
                description: nil,
                maxTurns: nil,
                context: "Example project context",
                system: "Example system context"
            )
        ),
        assistantsViewModel: AssistantsViewModel()
    ))
}