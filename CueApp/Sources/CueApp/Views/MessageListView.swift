import SwiftUI

struct MessagesListView: View {
    let messages: [MessageModel]
    let shouldAutoScroll: Bool

    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasInitialized = false
    @State private var isUserScrolling = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Flexible spacer to push content to bottom
                    Spacer(minLength: 0)
                        .frame(maxHeight: .infinity)

                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding(.bottom, 10)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(iOS)
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { _ in
                        isUserScrolling = true
                        dismissKeyboard()
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isUserScrolling = false
                        }
                    }
            )
            #endif
            .onAppear {
                scrollProxy = proxy

                // Only attempt to scroll if we have messages
                if shouldAutoScroll && !hasInitialized && !messages.isEmpty {
                    performInitialScroll()
                }
            }
            .onChange(of: messages) { oldMessages, newMessages in
                // If this is the first time we're getting messages and we haven't scrolled yet
                if oldMessages.isEmpty && !newMessages.isEmpty && shouldAutoScroll && !hasInitialized {
                    performInitialScroll()
                    return
                }

                guard !newMessages.isEmpty else { return }

                let hasNewMessages = newMessages.count > oldMessages.count
                let isAtBottom = shouldAutoScroll && (hasInitialized || hasNewMessages)

                if isAtBottom && !isUserScrolling {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(newMessages.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func performInitialScroll() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                scrollProxy?.scrollTo(messages.last?.id, anchor: .bottom)
            }
            hasInitialized = true
        }
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
