import Foundation
import SwiftUI

/// A consolidated model that combines an Assistant with its associated ClientStatus
struct AssistantWithStatus: Identifiable, Equatable, Hashable {
    let assistant: Assistant
    let status: ClientStatus?
    
    var id: String { assistant.id }
    var name: String { assistant.name }
    var isPrimary: Bool { assistant.isPrimary }
    var isOnline: Bool { status?.isOnline == true }
    var lastUpdated: Date { status?.lastUpdated ?? assistant.updatedAt }
    var lastMessage: String? { status?.lastMessage }
    var runnerId: String? { status?.runnerId }
    
    // Computed property for the UI
    var statusIndicator: String {
        if isOnline {
            return "Online"
        } else if let lastMessage = lastMessage, !lastMessage.isEmpty {
            return "Last message: \(lastMessage)"
        } else {
            return "Offline"
        }
    }
    
    // Color property for the UI
    var statusColor: Color {
        isOnline ? .green : .secondary
    }
}

// Extension for sorting assistants
extension Array where Element == AssistantWithStatus {
    /// Sort assistants by online status first, then by latest interaction time
    func sortedByStatusAndActivity() -> [AssistantWithStatus] {
        self.sorted { first, second in
            // First sort by primary status (primary assistants first)
            if first.isPrimary && !second.isPrimary {
                return true
            } else if !first.isPrimary && second.isPrimary {
                return false
            }
            
            // Then sort by online status (online assistants first)
            if first.isOnline && !second.isOnline {
                return true
            } else if !first.isOnline && second.isOnline {
                return false
            }
            
            // Finally sort by last updated time (most recent first)
            return first.lastUpdated > second.lastUpdated
        }
    }
}