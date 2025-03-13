import SwiftUI
import Combine
import Dependencies
import CueCommon

@MainActor
final class AssistantDetailViewModel: ObservableObject {
    @Dependency(\.assistantRepository) private var assistantRepository
    let onUpdate: ((Assistant) -> Void)?

    @Published var assistant: Assistant
    @Published var showingNameEdit = false
    @Published var showingInstructionEdit = false
    @Published var showingDescriptionEdit = false
    @Published var showingMaxTurnsEdit = false
    @Published var showCopiedAlert = false
    @Published var error: ChatError?

    @Published var newName = ""
    @Published var selectedModel = ChatModel.gpt4oMini
    @Published var instruction = ""
    @Published var description = ""
    @Published var maxTurns = 30
    @Published var tempMaxTurns = ""

    let availableModelsV2 = [
        ChatModel.claude37Sonnet,
        ChatModel.o3mini,
        ChatModel.gpt4oMini,
        ChatModel.gpt4o,
        ChatModel.gemini20Pro,
    ]

    init(
        assistant: Assistant,
        onUpdate: ((Assistant) -> Void)? = nil
    ) {
        self.assistant = assistant
        self.onUpdate = onUpdate

        if let modelId = assistant.metadata?.model, let chatModel = ChatModel(rawString: modelId) {
            self.selectedModel = chatModel
        } else {
            self.selectedModel = .gpt4oMini
        }

        self.instruction = assistant.metadata?.instruction ?? ""
        self.description = assistant.metadata?.description ?? ""
        self.maxTurns = assistant.metadata?.maxTurns ?? 30
    }

    func updateName() async {
        switch await assistantRepository.updateAssistant(id: assistant.id, name: newName, metadata: nil) {
        case .success(let assistant):
            self.assistant = assistant
        case .failure(let error):
            handleError(error)
        }
    }

    func updateMetadata(
        isPrimary: Bool? = nil,
        model: String? = nil,
        instruction: String? = nil,
        description: String? = nil,
        maxTurns: Int? = nil,
        context: JSONValue? = nil,
        tools: [String]? = nil,
        color: String? = nil
    ) async -> Assistant? {
        let metadata = AssistantMetadataUpdate(
            isPrimary: isPrimary,
            model: model,
            instruction: instruction,
            description: description,
            maxTurns: maxTurns,
            context: context,
            tools: tools,
            color: color
        )

        switch await assistantRepository.updateAssistant(id: self.assistant.id, name: nil, metadata: metadata) {
        case .success(let assistant):
            self.assistant = assistant
            AppLog.log.debug("Updated metadata for assistant: \(self.assistant.id)")
            return assistant
        case .failure(let error):
            handleError(error)
        }
        return nil
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
            _ = await updateMetadata(maxTurns: value)
            maxTurns = value
        }
    }

    func validateMaxTurns(_ text: String) -> Bool {
        guard let number = Int(text), number > 0 else { return false }
        return true
    }
    private func handleError(_ error: Error) {
        self.error = ChatError.unknownError(error.localizedDescription)
        ErrorLogger.log(ChatError.unknownError(error.localizedDescription))
    }
}
