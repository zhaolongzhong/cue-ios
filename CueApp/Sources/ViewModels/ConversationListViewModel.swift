import Foundation
import Combine

@MainActor
public class ConversationListViewModel: ObservableObject {
    public struct ConversationItem: Identifiable {
        public let id: String
        public let title: String
        public let latestMessagePreview: String?
        public let latestMessageAt: Date?
        public let hasUnread: Bool
        public let unreadIndicatorType: UnreadIndicatorType
        
        public enum UnreadIndicatorType {
            case none
            case dot
            case preview
            case newThread
        }
    }
    
    @Published private(set) public var conversations: [ConversationItem] = []
    private let repository: ConversationRepository
    private let userId: String
    
    public init(repository: ConversationRepository, userId: String) {
        self.repository = repository
        self.userId = userId
    }
    
    public func loadConversations() async {
        do {
            let statuses = try await repository.getConversationsStatus(userId: userId)
            self.conversations = statuses.map { status in
                ConversationItem(
                    id: status.conversation.id,
                    title: status.conversation.title,
                    latestMessagePreview: status.conversation.latestMessagePreview,
                    latestMessageAt: status.conversation.latestMessageAt,
                    hasUnread: isUnread(
                        lastReadAt: status.readStatus?.lastReadAt,
                        latestMessageAt: status.conversation.latestMessageAt
                    ),
                    unreadIndicatorType: determineIndicatorType(
                        lastReadAt: status.readStatus?.lastReadAt,
                        latestMessageAt: status.conversation.latestMessageAt
                    )
                )
            }
        } catch {
            // Handle error appropriately
            print("Error loading conversations: \(error)")
        }
    }
    
    public func markAsRead(_ conversationId: String) async {
        do {
            try await repository.markAsRead(
                conversationId: conversationId,
                userId: userId
            )
            // Refresh conversations after marking as read
            await loadConversations()
        } catch {
            print("Error marking conversation as read: \(error)")
        }
    }
    
    private func isUnread(lastReadAt: Date?, latestMessageAt: Date?) -> Bool {
        guard let latestMessageAt = latestMessageAt else { return false }
        guard let lastReadAt = lastReadAt else { return true }
        return latestMessageAt > lastReadAt
    }
    
    private func determineIndicatorType(
        lastReadAt: Date?,
        latestMessageAt: Date?
    ) -> ConversationItem.UnreadIndicatorType {
        guard isUnread(lastReadAt: lastReadAt, latestMessageAt: latestMessageAt) else {
            return .none
        }
        
        if lastReadAt == nil {
            return .newThread
        }
        
        return .preview
    }
}