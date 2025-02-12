import SwiftUI

@ViewBuilder
func categoryIcon(for category: EmailCategory) -> some View {
    switch category {
    case .newsletters:
        Image(systemName: "newspaper")
            .foregroundStyle(.primary.opacity(0.8))
    case .updates:
        Image(systemName: "bell")
            .foregroundStyle(.primary.opacity(0.8))
    case .actionItems:
        Image(systemName: "checklist")
            .foregroundStyle(.primary.opacity(0.8))
    case .replies:
        Image(systemName: "arrow.turn.up.left")
            .foregroundStyle(.primary.opacity(0.8))
    }
}
