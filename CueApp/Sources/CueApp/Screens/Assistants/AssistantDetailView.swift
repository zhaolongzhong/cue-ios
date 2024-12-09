import SwiftUI

struct AssistantDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AssistantDetailViewModel

    init(
        assistant: Assistant,
        assistantsViewModel: AssistantsViewModel,
        onUpdate: @escaping (Assistant) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: AssistantDetailViewModel(
                assistant: assistant,
                assistantsViewModel: assistantsViewModel,
                onUpdate: onUpdate
            )
        )
    }

    var body: some View {
        List {
            Section("Details") {
                Button {
                    viewModel.prepareNameEdit()
                } label: {
                    LabeledContent("Name", value: viewModel.assistant.name)
                }

                AssistantIDView(id: viewModel.assistant.id)

                Picker("Model", selection: $viewModel.selectedModel) {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        Text(model)
                            .tag(model)
                    }
                }
                .onChange(of: viewModel.selectedModel) { _, newValue in
                    Task {
                        await viewModel.updateMetadata(model: newValue)
                    }
                }

                Button {
                    viewModel.showingInstructionEdit = true
                } label: {
                    SettingsRow(
                        systemName: "text.bubble",
                        title: "Instruction"
                    )
                }

                Button {
                    viewModel.showingDescriptionEdit = true
                } label: {
                    SettingsRow(
                        systemName: "doc.text",
                        title: "Description"
                    )
                }

                Button {
                    viewModel.prepareMaxTurnsEdit()
                } label: {
                    SettingsRow(
                        systemName: "number",
                        title: "Max Turns",
                        value: viewModel.maxTurns.isEmpty ? "Not set" : viewModel.maxTurns
                    )
                }
            }
        }
        .navigationTitle("Assistant Details")
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.automatic)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        #endif
        .inputAlert(
            title: "Update Name",
            message: "Enter a new name for this assistant",
            text: $viewModel.newName,
            isPresented: $viewModel.showingNameEdit,
            onSave: { _ in
                Task {
                    await viewModel.updateName()
                }
            }
        )
        .inputAlert(
            title: "Set Max Turns",
            message: "Enter the maximum number of conversation turns",
            text: $viewModel.tempMaxTurns,
            isPresented: $viewModel.showingMaxTurnsEdit,
            placeholder: "Enter number",
            isNumeric: true,
            validator: viewModel.validateMaxTurns,
            onSave: viewModel.handleMaxTurnsUpdate
        )
        .textFieldEditor(
            title: "Edit Instruction",
            text: $viewModel.instruction,
            isPresented: $viewModel.showingInstructionEdit
        ) { newValue in
            Task {
                await viewModel.updateMetadata(instruction: newValue)
            }
        }
        .textFieldEditor(
            title: "Edit Description",
            text: $viewModel.description,
            isPresented: $viewModel.showingDescriptionEdit
        ) { newValue in
            Task {
                await viewModel.updateMetadata(description: newValue)
            }
        }
    }
}
