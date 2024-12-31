import SwiftUI

struct FullMessageView: View {
    @Environment(\.dismiss) var dismiss
    let message: MessageModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                DismissButton(action: { dismiss() })
            }
            .padding([.top, .horizontal])

            ScrollView {
                MessageBubble(
                    role: message.author.role,
                    content: message.getText(),
                    isExpanded: true
                )
                .padding()
            }
            Spacer()
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        .frame(idealWidth: 800, idealHeight: 600)
        .resizableSheet()
        #endif
    }
}
