import Foundation
import SwiftUI
import Dependencies
import CueCommon
import Combine

@MainActor
public class ConversationsViewModel: ObservableObject {
    @Dependency(\.conversationRepository) private var conversationRepository

    // Main conversation state
    @Published var conversations: [ConversationModel] = []
    @Published var selectedConversationId: String?
    @Published var isLoading = false
    @Published var error: Error?

    @Published var searchText: String = ""
    @Published var currentProvider: Provider?
    @Published var sortOrder: SortOrder = .dateModifiedDesc

    // Multi-select state
    @Published var isSelectMode: Bool = false
    @Published var selectedConversationIds: Set<String> = []

    private let minimumSearchLength = 3
    private let searchDebounceTime: TimeInterval = 0.3
    private var searchTask: Task<Void, Never>?
    private var allConversations: [ConversationModel] = []

    private var cancellables = Set<AnyCancellable>()

    public enum SortOrder {
        case dateModifiedDesc
        case dateModifiedAsc
        case titleAsc
        case titleDesc
    }

    public init(selectedConversationId: String? = nil, provider: Provider? = nil) {
        self.selectedConversationId = selectedConversationId
        self.currentProvider = provider

        setupSearchDebounce()

        if let provider = provider {
            Task {
                await fetchConversations(provider: provider)
            }
        }
    }

    private func setupSearchDebounce() {
        // Use Combine to create a debounced publisher for the search text
        $searchText
            .debounce(for: .seconds(searchDebounceTime), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self = self else { return }
                // Only filter if we have enough characters or if clearing the search
                if text.isEmpty || text.count >= self.minimumSearchLength {
                    self.applyFiltersAndUpdateConversations()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch Operations

    /// Fetches conversations for a specific provider
    public func fetchConversations(provider: Provider? = nil) async {
        let providerToUse = provider ?? currentProvider

        guard let providerToUse = providerToUse else {
            self.error = NSError(domain: "ConversationManager", code: 1,
                                 userInfo: [NSLocalizedDescriptionKey: "No provider specified"])
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await conversationRepository.fetchConversationsByProvider(
                provider: providerToUse,
                limit: 100,
                offset: 0
            )
            AppLog.log.debug("Fetched \(result.count) conversations")

            self.allConversations = result
            applyFiltersAndUpdateConversations()

            // If we don't have a selected conversation yet, select the first one if available
            if selectedConversationId == nil, let firstId = conversations.first?.id {
                selectedConversationId = firstId
            }
        } catch {
            self.error = error
            AppLog.log.error("Failed to fetch conversations: \(error)")
        }
    }

    /// Refreshes the current conversation list
    public func refreshConversations() async {
        if let provider = currentProvider {
            await fetchConversations(provider: provider)
        }
    }

    // MARK: - Search and Filtering

    /// Applies current filters and sort to update the conversations array
    private func applyFiltersAndUpdateConversations() {
        // First apply search filter
        var filtered = allConversations

        // Only apply search if we have at least the minimum number of characters
        if !searchText.isEmpty && searchText.count >= minimumSearchLength {
            AppLog.log.debug("Filtering by search: \(self.searchText)")
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
            AppLog.log.debug("Found \(filtered.count) matching conversations")
        }

        // Then apply sorting
        switch sortOrder {
        case .dateModifiedDesc:
            filtered.sort { $0.updatedAt > $1.updatedAt }
        case .dateModifiedAsc:
            filtered.sort { $0.updatedAt < $1.updatedAt }
        case .titleAsc:
            filtered.sort { $0.title < $1.title }
        case .titleDesc:
            filtered.sort { $0.title > $1.title }
        }

        // Update the published property
        self.conversations = filtered
    }

    /// Updates the sort order
    public func updateSortOrder(_ order: SortOrder) {
        sortOrder = order
        applyFiltersAndUpdateConversations()
    }

    /// Updates the provider filter
    public func updateProvider(_ provider: Provider?) {
        currentProvider = provider
        Task {
            if let provider = provider {
                await fetchConversations(provider: provider)
            } else {
                allConversations = []
                conversations = []
            }
        }
    }

    // MARK: - CRUD Operations

    /// Creates a new conversation
    public func createConversation(title: String = "New Conversation", provider: Provider) async -> String? {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await conversationRepository.createConversation(
                title: title,
                assistantId: "",
                isPrimary: false,
                provider: provider
            )
            // Add to local arrays
            self.allConversations.insert(result, at: 0)
            applyFiltersAndUpdateConversations()
            return result.id
        } catch {
            self.error = error
            AppLog.log.error("Failed to create conversation: \(error)")
            return nil
        }
    }

    /// Updates the title of a conversation
    public func updateTitle(for conversationId: String, newTitle: String) async -> Bool {
        guard let index = allConversations.firstIndex(where: { $0.id == conversationId }) else {
            return false
        }
        let conversation = allConversations[index]
        let newConversation = ConversationModel(
            id: conversationId,
            title: newTitle,
            createdAt: conversation.createdAt,
            updatedAt: Date(),
            assistantId: nil,
            metadata: ConversationMetadata(isPrimary: false)
        )

        do {
            try await conversationRepository.update(newConversation)
            // Update in local array
            if let index = allConversations.firstIndex(where: { $0.id == conversationId }) {
                allConversations[index] = newConversation
                applyFiltersAndUpdateConversations()
            }
            return true
        } catch {
            self.error = error
            AppLog.log.error("Failed to update conversation title: \(error)")
            return false
        }
    }

    /// Deletes a conversation
    public func deleteConversation(_ conversationId: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await conversationRepository.delete(id: conversationId)
            // Remove from local arrays
            allConversations.removeAll { $0.id == conversationId }
            applyFiltersAndUpdateConversations()

            // If the deleted conversation was selected, select another one
            if selectedConversationId == conversationId {
                selectedConversationId = conversations.first?.id
            }
            return true
        } catch {
            self.error = error
            AppLog.log.error("Failed to delete conversation: \(error)")
            return false
        }
    }

    /// Delete multiple selected conversations
    public func deleteSelectedConversations() async -> Bool {
        isLoading = true
        defer {
            isLoading = false
            // Exit select mode after deletion
            isSelectMode = false
            selectedConversationIds.removeAll()
        }

        var success = true
        for conversationId in selectedConversationIds {
            let result = await deleteConversation(conversationId)
            if !result {
                success = false
            }
        }

        return success
    }

    // MARK: - Selection Handling

    /// Selects a conversation by ID
    public func selectConversation(_ conversationId: String?) {
        selectedConversationId = conversationId
    }

    // MARK: - Multi-select Handling

    /// Toggle select mode
    public func toggleSelectMode() {
        isSelectMode.toggle()
        if !isSelectMode {
            selectedConversationIds.removeAll()
        }
    }

    /// Toggle selection of a conversation
    public func toggleConversationSelection(_ conversationId: String) {
        if selectedConversationIds.contains(conversationId) {
            selectedConversationIds.remove(conversationId)
        } else {
            selectedConversationIds.insert(conversationId)
        }
    }

    /// Select all conversations
    public func selectAllConversations() {
        selectedConversationIds = Set(conversations.map { $0.id })
    }

    /// Deselect all conversations
    public func deselectAllConversations() {
        selectedConversationIds.removeAll()
    }

    /// Check if a conversation is selected
    public func isConversationSelected(_ conversationId: String) -> Bool {
        return selectedConversationIds.contains(conversationId)
    }

    // MARK: - Error Handling

    /// Clears the current error
    public func clearError() {
        error = nil
    }
}
