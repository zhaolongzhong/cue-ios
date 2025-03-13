import SwiftUI

struct AssistantDetailView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AssistantDetailViewModel
    @State private var showColorPicker = false
    let onUpdate: ((Assistant) -> Void)?

    init(
        assistant: Assistant,
        onUpdate: ((Assistant) -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: AssistantDetailViewModel(
                assistant: assistant
            )
        )
        self.onUpdate = onUpdate
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
                        if let assistant = await viewModel.updateMetadata(color: color.hexString) {
                            onUpdate?(assistant)
                        }
                    }
                }
            )
        }
        .onChange(of: viewModel.assistant) { _, assistant in
            onUpdate?(assistant)
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
                    // Remove the button and use a custom view for context menu support
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Name")
                                .font(.body)
                        }
                        Spacer()

                        Text(viewModel.assistant.name)
                            .foregroundColor(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle()) // Important for tap gesture
                    .onTapGesture {
                        viewModel.prepareNameEdit()
                    }
                    .contextMenu {
                        Button {
                            #if os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(viewModel.assistant.id, forType: .string)
                            #else
                            UIPasteboard.general.string = viewModel.assistant.id
                            #endif
                        } label: {
                            Label("Copy Assistant ID", systemImage: "doc.on.doc")
                        }
                    }

                    Divider()

                    settingRow(
                        title: "Bio",
                        description: "Brief description of this assistant",
                        value: viewModel.description.isEmpty ? "Add" : ""
                    ) {
                        viewModel.showingDescriptionEdit = true
                    }
                }
            } header: {
                AssistantDetailSectionHeader(title: "Basic")
            }

            // Assistant Settings Section
            Section {
                GroupBox {
                    settingRow(
                        title: "Instruction",
                        description: "Instruction for the assistant",
                        value: viewModel.instruction.isEmpty ? "Add" : ""
                    ) {
                        viewModel.showingInstructionEdit = true
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Model")
                                .font(.body)
                        }
                        Spacer()
                        Picker("", selection: $viewModel.selectedModel) {
                            ForEach(viewModel.availableModelsV2, id: \.self) { model in
                                Text(model.displayName)
                                    .lineLimit(1)
                                    .tag(model)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(minWidth: 120)
                        .onReceive(viewModel.$selectedModel) { newModel in
                            Task {
                                await viewModel.updateMetadata(model: newModel.id)
                            }
                        }
                    }

                    Divider()

                    settingRow(
                        title: "Max Steps",
                        description: "Maximum number of steps to run automatically",
                        value: "\(viewModel.maxTurns)"
                    ) {
                        viewModel.prepareMaxTurnsEdit()
                    }
                }
            } header: {
                AssistantDetailSectionHeader(title: "Settings")
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
