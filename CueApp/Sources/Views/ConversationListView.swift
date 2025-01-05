import SwiftUI

public struct ConversationListView: View {
    @StateObject private var viewModel: ConversationListViewModel
    
    public init(viewModel: ConversationListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        List(viewModel.conversations) { item in
            ConversationRow(item: item)
                .swipeActions {
                    Button("Mark Read") {
                        Task {
                            await viewModel.markAsRead(item.id)
                        }
                    }
                    .tint(.blue)
                }
        }
        .refreshable {
            await viewModel.loadConversations()
        }
        .task {
            await viewModel.loadConversations()
        }
    }
}

struct ConversationRow: View {
    let item: ConversationListViewModel.ConversationItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    
                    if item.hasUnread {
                        UnreadIndicator(type: item.unreadIndicatorType)
                    }
                }
                
                if let preview = item.latestMessagePreview {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if let date = item.latestMessageAt {
                Text(date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct UnreadIndicator: View {
    let type: ConversationListViewModel.ConversationItem.UnreadIndicatorType
    
    var body: some View {
        switch type {
        case .none:
            EmptyView()
            
        case .dot:
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
            
        case .preview:
            Text("New")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(Capsule())
            
        case .newThread:
            Text("New Thread")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }
}