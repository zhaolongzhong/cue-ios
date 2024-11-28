import SwiftUI

public struct MessagesListView: View {
    let messages: [MessageModel]
    let shouldAutoScroll: Bool
    
    @State private var hasScrolledToBottom = false
    @State private var lastMessageId: Message.ID?
    
    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id(ScrollAnchor.id)
                }
                .padding(.vertical, 8)
            }
            #if os(iOS)
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    dismissKeyboard()
                }
            )
            #endif
            .onChange(of: messages) { oldMessages, newMessages in
                let hasNewMessages = newMessages.count > oldMessages.count
                let currentLastMessageId = newMessages.last?.id
                
                // For new messages after initial load
                if hasScrolledToBottom && shouldAutoScroll && hasNewMessages {
                    withAnimation {
                        proxy.scrollTo(ScrollAnchor.id, anchor: .bottom)
                    }
                }
                
                lastMessageId = currentLastMessageId
                
                // Initial load: scroll to bottom without animation
                if !hasScrolledToBottom && !newMessages.isEmpty {
                    proxy.scrollTo(ScrollAnchor.id, anchor: .bottom)
                    hasScrolledToBottom = true
                }
            }
            // Initial position at bottom when view appears
            .task {
                if !messages.isEmpty && !hasScrolledToBottom {
                    proxy.scrollTo(ScrollAnchor.id, anchor: .bottom)
                    hasScrolledToBottom = true
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height < -50 && value.velocity.height < -200 {
                            withAnimation {
                                proxy.scrollTo(ScrollAnchor.id, anchor: .bottom)
                            }
                        }
                    }
            )
        }
        .background(AppTheme.Colors.background)
    }

    #if os(iOS)
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                     to: nil,
                                     from: nil,
                                     for: nil)
    }
    #endif
}

struct SendButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundStyle(.white, isEnabled ? .blue : .gray)
        }
        .disabled(!isEnabled)
    }
}

struct ScrollAnchor: View {
    static let id = "ScrollAnchor"

    var body: some View {
        Color.clear
            .frame(height: 1)
            .id(Self.id)
    }
}

public struct LoadingOverlay: View {
    let isVisible: Bool

    public var body: some View {
        if isVisible {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
        }
    }
}

#Preview {
    @Previewable @State var inputMessage: String = ""
    MessageInputView(inputMessage: $inputMessage, isEnabled: true) {

    }
}
