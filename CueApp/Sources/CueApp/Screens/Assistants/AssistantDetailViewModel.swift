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
    @Published var showingProjectContextEdit = false
    @Published var showingSystemContextEdit = false
    @Published var showCopiedAlert = false

    @Published var newName = ""
    @Published var selectedModel = ""
    @Published var instruction = ""
    @Published var description = ""
    @Published var maxTurns = ""
    @Published var tempMaxTurns = ""
    @Published var projectContext = ""
    @Published var systemContext = ""

    let availableModels = [
        "claude-3-5-sonnet-20241022",
        "gpt-4o-mini",
        "gpt-4o",
        "o1-mini"
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
        self.maxTurns = String(assistant.metadata?.maxTurns ?? 0)
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
        context: String? = nil,
        system: String? = nil
    ) async {
        guard let updatedAssistant = await assistantsViewModel.updateMetadata(
            id: assistant.id,
            model: model,
            instruction: instruction,
            description: description,
            maxTurns: maxTurns,
            context: context,
            system: system
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
        tempMaxTurns = maxTurns
        showingMaxTurnsEdit = true
    }

    func handleMaxTurnsUpdate(_ value: String) {
        if let turns = Int(value) {
            maxTurns = String(turns)
            Task {
                await updateMetadata(maxTurns: turns)
            }
        }
    }

    func validateMaxTurns(_ text: String) -> Bool {
        guard let number = Int(text), number > 0 else { return false }
        return true
    }
}
