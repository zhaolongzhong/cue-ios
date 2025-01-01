import SwiftUI

struct AssistantDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AssistantDetailViewModel

    init(
        assistant: Assistant,
        assistantsViewModel: AssistantsViewModel,
        onUpdate: ((Assistant) -> Void)? = nil
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
            Button {
                viewModel.prepareNameEdit()
            } label: {
                SettingsRow(
                    systemName: "person.circle",
                    title: "Name",
                    value: viewModel.assistant.name
                )
            }
            .buttonStyle(.plain)

            AssistantIDView(id: viewModel.assistant.id)

            SettingsRow(
                systemName: "gearshape",
                title: "Model",
                value: "",
                trailing: AnyView(
                    Picker("", selection: $viewModel.selectedModel) {
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Text(model)
                                .tag(model)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(MenuPickerStyle())
                    .font(.system(size: 12))
                    .padding(.vertical, 0)
                    .frame(height: 30)
                    .tint(Color.secondary)
                    .onChange(of: viewModel.selectedModel) { _, newValue in
                        Task {
                            await viewModel.updateMetadata(model: newValue)
                        }
                    }
                )
            )

            Button {
                viewModel.showingInstructionEdit = true
            } label: {
                SettingsRow(
                    systemName: "text.bubble",
                    title: "Instruction",
                    showChevron: true
                )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.showingDescriptionEdit = true
            } label: {
                SettingsRow(
                    systemName: "doc.text",
                    title: "Description",
                    showChevron: true
                )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.prepareMaxTurnsEdit()
            } label: {
                SettingsRow(
                    systemName: "number",
                    title: "Max Turns",
                    value: viewModel.maxTurns.isEmpty ? "Not set" : viewModel.maxTurns,
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Assistant Details")
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .defaultWindowSize()
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
