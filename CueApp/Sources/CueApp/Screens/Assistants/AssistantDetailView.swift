import SwiftUI

struct AssistantDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AssistantDetailViewModel
    @State private var showColorPicker = false

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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                assistantDetailsHeader
                Divider()
                assistantSettingsSection
            }
            .padding()
        }
        .navigationTitle("\(viewModel.assistant.name) Details")
        .defaultNavigationBar(title: "\(viewModel.assistant.name) Details")
        .alert("Update Name", isPresented: $viewModel.showingNameEdit) {
            TextField("Enter name", text: $viewModel.newName)
                .autocorrectionDisabled()

            Button("Cancel", role: .cancel) {
                viewModel.newName = viewModel.assistant.name
            }

            Button("Save") {
                Task {
                    await viewModel.updateName()
                }
            }
        } message: {
            Text("Enter a new name for this assistant")
        }
        .numberInputAlert(
            title: "Set Max Turns",
            message: "Enter the maximum number of turns for agent automatically run.",
            isPresented: $viewModel.showingMaxTurnsEdit,
            inputValue: $viewModel.tempMaxTurns,
            onSave: { newValue in
                viewModel.handleMaxTurnsUpdate(newValue)
            }
        )
        .sheet(isPresented: $viewModel.showingInstructionEdit) {
            TextFieldEditorSheet(
                title: "Edit Instruction",
                text: $viewModel.instruction
            ) { newValue in
                Task {
                    await viewModel.updateMetadata(instruction: newValue)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingDescriptionEdit) {
            TextFieldEditorSheet(
                title: "Edit Description",
                text: $viewModel.description
            ) { newValue in
                Task {
                    await viewModel.updateMetadata(description: newValue)
                }
            }
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerSheetV2(
                colorPalette: viewModel.assistant.assistantColor,
                onColorSelected: { color in
                    Task {
                        await viewModel.updateMetadata(color: color)
                    }
                }
            )
        }
    }

    private var assistantDetailsHeader: some View {
        HStack(spacing: 12) {
            Button {
                showColorPicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(viewModel.assistant.assistantColor.color)
                        .frame(width: 40, height: 40)

                    InitialsAvatar(text: viewModel.assistant.name.prefix(1).uppercased(), size: 36)
                }
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading) {
                Text(viewModel.assistant.name)
                    .font(.headline)
            }
        }
    }

    private var assistantSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Basic Settings Section
            Section {
                GroupBox {
                    settingRow(
                        title: "Name",
                        value: viewModel.assistant.name
                    ) {
                        viewModel.prepareNameEdit()
                    }
                    .padding(.all, 4)
                    Divider()
                        .padding(.all, 4)

                    settingRow(
                        title: "ID",
                        value: viewModel.assistant.id,
                        isCopiable: true
                    ) {
                        // No action for ID, just for display
                    }
                    .padding(.all, 4)
                }
            } header: {
                AssistantDetailSectionHeader(title: "Basic")
            }

            // Model Settings Section
            Section {
                GroupBox {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Model")
                                .font(.body)
                        }
                        Spacer()
                        Picker("", selection: $viewModel.selectedModel) {
                            ForEach(viewModel.availableModels, id: \.self) { model in
                                Text(model)
                                    .lineLimit(1)
                                    .tag(model)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(minWidth: 120)
                        .onChange(of: viewModel.selectedModel) { _, newValue in
                            Task {
                                await viewModel.updateMetadata(model: newValue)
                            }
                        }
                    }
                    .padding(.all, 4)

                    Divider()
                        .padding(.all, 4)

                    settingRow(
                        title: "Max Turns",
                        description: "Maximum number of turns to run automatically",
                        value: "\(viewModel.maxTurns)"
                    ) {
                        viewModel.prepareMaxTurnsEdit()
                    }
                    .padding(.all, 4)
                }
            } header: {
                AssistantDetailSectionHeader(title: "Model Settings")
            }

            // Content Settings Section
            Section {
                GroupBox {
                    settingRow(
                        title: "Instruction",
                        description: "System prompt for the assistant",
                        value: viewModel.instruction.isEmpty ? "Not set" : "Edit"
                    ) {
                        viewModel.showingInstructionEdit = true
                    }
                    .padding(.all, 4)

                    Divider()
                        .padding(.all, 4)

                    settingRow(
                        title: "Description",
                        description: "Brief description of this assistant",
                        value: viewModel.description.isEmpty ? "Not set" : "Edit"
                    ) {
                        viewModel.showingDescriptionEdit = true
                    }
                    .padding(.all, 4)
                }
            } header: {
                AssistantDetailSectionHeader(title: "Content")
            }
        }
    }

    private func settingRow(
        title: String,
        description: String? = nil,
        value: String,
        isCopiable: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.body)
                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                if isCopiable {
                    HStack(spacing: 4) {
                        Text(value)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(value, forType: .string)
                            #else
                            UIPasteboard.general.string = value
                            #endif
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                } else {
                    Text(value)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AssistantDetailSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.almostPrimary)
    }
}
