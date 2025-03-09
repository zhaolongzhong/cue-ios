import SwiftUI
import Combine

@MainActor
final class AssistantDetailViewModel: ObservableObject {
    let assistantsViewModel: AssistantsViewModel
    let onUpdate: ((Assistant) -> Void)?

    @Published var assistant: Assistant
    @Published var showingNameEdit = false
    @Published var showingInstructionEdit = false
    @Published var showingDescriptionEdit = false
    @Published var showingMaxTurnsEdit = false
    @Published var showCopiedAlert = false

    @Published var newName = ""
    @Published var selectedModel = ""
    @Published var instruction = ""
    @Published var description = ""
    @Published var maxTurns = 30
    @Published var tempMaxTurns = ""
    @Published var useCueClient = false

    let availableModels = [
        "claude-3-7-sonnet-20250219",
        "o3-mini",
        "gpt-4o-mini",
        "gpt-4o"
    ]

    init(
        assistant: Assistant,
        assistantsViewModel: AssistantsViewModel,
        onUpdate: ((Assistant) -> Void)? = nil
    ) {
        self.assistant = assistant
        self.assistantsViewModel = assistantsViewModel
        self.onUpdate = onUpdate

        // Initialize fields
        self.selectedModel = assistant.metadata?.model ?? availableModels[0]
        self.instruction = assistant.metadata?.instruction ?? ""
        self.description = assistant.metadata?.description ?? ""
        self.maxTurns = assistant.metadata?.maxTurns ?? 30
        self.useCueClient = assistant.metadata?.useCueClient ?? false
    }

    func updateName() async {
        guard let updatedAssistant = await assistantsViewModel.updateAssistantName(
            id: assistant.id,
            name: newName
        ) else {
            AppLog.log.error("Error when update assistant.")
            return
        }
        self.assistant = updatedAssistant
        onUpdate?(updatedAssistant)
    }

    func updateMetadata(
        model: String? = nil,
        instruction: String? = nil,
        description: String? = nil,
        maxTurns: Int? = nil,
        useCueClient: Bool? = nil,
        color: AppTheme.ColorPalette? = nil
    ) async {
        guard let updatedAssistant = await assistantsViewModel.updateMetadata(
            id: assistant.id,
            model: model,
            instruction: instruction,
            description: description,
            maxTurns: maxTurns,
            useCueClient: useCueClient,
            color: color?.hexString
        ) else {
            AppLog.log.error("Error when updating assistant metadata.")
            return
        }
        self.assistant = updatedAssistant
        onUpdate?(updatedAssistant)
    }

    func prepareNameEdit() {
        newName = assistant.name
        showingNameEdit = true
    }

    func prepareMaxTurnsEdit() {
        tempMaxTurns = String(maxTurns)
        showingMaxTurnsEdit = true
    }

    func handleMaxTurnsUpdate(_ value: Int) {
        Task {
            await updateMetadata(maxTurns: value)
            maxTurns = value
        }
    }

    func validateMaxTurns(_ text: String) -> Bool {
        guard let number = Int(text), number > 0 else { return false }
        return true
    }
}
