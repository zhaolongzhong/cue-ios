import SwiftUI

struct ChatDetailView: View {
    let chat: ChatItem

    var body: some View {
        VStack {
            Text("Selected: \(chat.name)")
                .font(.largeTitle)
                .padding()

            Spacer()
        }
    }
}

#Preview {
    ChatDetailView(chat: ChatItem(id: 1, name: "Chat 1"))
}
