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
        Button(action: onTap) {
            SettingsRow(
                systemIcon: "person.circle",
                title: "Name",
                value: name
            )
        }
        .buttonStyle(.plain)
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
        Button(action: onTap) {
            SettingsRow(
                systemIcon: systemName,
                title: title,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }
}

struct AssistantMaxTurnsRow: View {
    let maxTurns: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            SettingsRow(
                systemIcon: "number",
                title: "Max Turns",
                value: String(maxTurns),
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TextFieldEditorSheet
struct TextFieldEditorSheet: View {
    let title: String
    @Binding var text: String
    let onSave: (String) -> Void
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
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .padding(.all, 8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                .navigationTitle(title)
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
                        Button("Save") {
                            onSave(text)
                            dismiss()
                        }
                    }
                }
                .padding(.all, 8)
        }
    }

    private var macOSView: some View {
        VStack {
            #if os(macOS)
            MacHeader(
                title: title,
                onDismiss: { dismiss() }
            )
            #endif
            VStack(spacing: 20) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary).opacity(0.2))

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)

                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}
