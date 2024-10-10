import SwiftUI
import Theme

struct ChatListView: View {
    let chatItems: [ChatItem]

    @Binding var selectedChat: ChatItem?
    @Binding var isMenuOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Chats")
                .font(.headline)
                .padding(.top, 50)
                .padding(.horizontal)

            List(chatItems) { chat in
                Button(action: {
                    withAnimation {
                        selectedChat = chat
                        isMenuOpen = false
                    }
                }) {
                    HStack {
                        Text(chat.name)
                            .font(.body)
                            .padding(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(selectedChat == chat ? Theme.Colors.secondaryBackground: Theme.Colors.tertiaryBackground)
                .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                .cornerRadius(3)
            }
            .listStyle(PlainListStyle())
            .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(Theme.Colors.tertiaryBackground))
    }
}

#Preview {
    @Previewable @State var selectedChat: ChatItem?
    @Previewable @State var isMenuOpen: Bool = false
    let chatItems: [ChatItem] = [
        ChatItem(id: 1, name: "Chat 1"),
        ChatItem(id: 2, name: "Chat 2"),
        ChatItem(id: 3, name: "Chat 3")
    ]

    ChatListView(chatItems: chatItems, selectedChat: $selectedChat, isMenuOpen: $isMenuOpen)
        .preferredColorScheme(.dark)
}
