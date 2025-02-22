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
        VStack {
            #if os(macOS)
            MacHeader(
                title: "Details",
                onDismiss: { dismiss() }
            )
            #endif

            AssistantDetailContent(viewModel: viewModel)
        }
        .defaultNavigationBar(title: "Details")
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
        .numberInputAlert(
            title: "Set Max Turns",
            message: "Enter the maximum number of turns for agent automaticaly run.",
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
}
}

// MARK: - Content View
struct AssistantDetailContent: View {
    @ObservedObject var viewModel: AssistantDetailViewModel

    var body: some View {
        List {
            AssistantNameRow(
                name: viewModel.assistant.name,
                onTap: viewModel.prepareNameEdit
            )

            AssistantIDView(id: viewModel.assistant.id)

            AssistantModelRow(
                selectedModel: $viewModel.selectedModel,
                availableModels: viewModel.availableModels
            ) { newValue in
                Task {
                    await viewModel.updateMetadata(model: newValue)
                }
            }

            AssistantSettingsRow(
                title: "Instruction",
                systemName: "text.bubble",
                onTap: { viewModel.showingInstructionEdit = true }
            )

            AssistantSettingsRow(
                title: "Description",
                systemName: "doc.text",
                onTap: { viewModel.showingDescriptionEdit = true }
            )

            AssistantMaxTurnsRow(
                maxTurns: viewModel.maxTurns,
                onTap: viewModel.prepareMaxTurnsEdit
            )
        }
        #if !os(iOS)
        .listStyle(.automatic)
        #endif
    }
}

// MARK: - Row Components
struct AssistantNameRow: View {
    let name: String
    let onTap: () -> Void

    var body: some View {
        SettingsRow(
            systemIcon: "person.circle",
            title: "Name",
            value: name,
            onTap: onTap
        )
    }
}

struct AssistantModelRow: View {
    @Binding var selectedModel: String
    let availableModels: [String]
    let onChange: (String) -> Void

    var body: some View {
        SettingsRow(
            systemIcon: "gearshape",
            title: "Model",
            trailing: AnyView(
                HStack {
                    Spacer()
                    Picker("", selection: $selectedModel) {
                        ForEach(availableModels, id: \.self) { model in
                            Text(model)
                                .lineLimit(1)
                                .tag(model)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(.system(size: 12))
                    #if os(macOS)
                    .frame(width: 120)
                    #else
                    .frame(minWidth: 120)
                    #endif
                    .tint(Color.secondary)
                    .onChange(of: selectedModel) { _, newValue in
                        onChange(newValue)
                    }
                }
            )
        )
    }
}

struct AssistantSettingsRow: View {
    let title: String
    let systemName: String
    let onTap: () -> Void

    var body: some View {
        SettingsRow(
            systemIcon: systemName,
            title: title,
            showChevron: true,
            onTap: onTap
        )
    }
}

struct AssistantMaxTurnsRow: View {
    let maxTurns: Int
    let onTap: () -> Void

    var body: some View {
        SettingsRow(
            systemIcon: "number",
            title: "Max Turns",
            value: String(maxTurns),
            showChevron: true,
            onTap: onTap
        )
    }
}
