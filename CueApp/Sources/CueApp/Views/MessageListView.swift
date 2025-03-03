import SwiftUI

struct MessagesListView: View {
    let messages: [CueChatMessage]
    let shouldAutoScroll: Bool
    let onScrollProxyReady: (ScrollViewProxy) -> Void
    let onLoadMore: () async -> Void
    let onShowMore: (CueChatMessage) -> Void

    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasInitialized = false
    @State private var showScrollButton = false
    @State private var previousMessageCount = 0
    @State private var hasScrolledToBottom = false
    @State private var forceScrollID = UUID()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MessagesList(
                messages: messages,
                scrollProxy: $scrollProxy,
                showScrollButton: $showScrollButton,
                shouldAutoScroll: shouldAutoScroll,
                onScrollProxyReady: onScrollProxyReady,
                hasInitialized: $hasInitialized,
                previousMessageCount: $previousMessageCount,
                hasScrolledToBottom: $hasScrolledToBottom,
                forceScrollID: forceScrollID,
                onLoadMore: onLoadMore,
                onShowMore: onShowMore
            )
            .refreshable {
                await onLoadMore()
            }
            .focusable(false)

            if showScrollButton {
                ScrollButton {
                    scrollToBottomImmediately()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .focusable(false)
            }
        }
    }

    private func scrollToBottomImmediately() {
        forceScrollID = UUID()
    }
}

struct MessagesList: View {
    let messages: [CueChatMessage]
    @Binding var scrollProxy: ScrollViewProxy?
    @Binding var showScrollButton: Bool
    let shouldAutoScroll: Bool
    let onScrollProxyReady: (ScrollViewProxy) -> Void
    @Binding var hasInitialized: Bool
    @Binding var previousMessageCount: Int
    @Binding var hasScrolledToBottom: Bool
    let forceScrollID: UUID
    let onLoadMore: () async -> Void
    let onShowMore: (CueChatMessage) -> Void
    @State var previousFirstVisibleIndex: Double = 0
    @State private var lastMessageContent: String = ""
    @State private var userHasManuallyScrolled = false
    @State private var isAtBottom = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(
                            message: message,
                            onShowMore: onShowMore
                        )
                        .id(message.id)
                        .background(MessageVisibilityTracker(index: index))
                    }
                }
                .padding(.vertical, 8)
            }
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    userHasManuallyScrolled = true
                }
            )
            .onPreferenceChange(ViewVisibilityKey.self) { visibility in
                if let firstVisibleIndex = visibility.first?.index {
                    #if os(macOS)
                    Task { @MainActor in
                        loadMoreMessages(firstVisibleIndex)
                    }
                    #endif
                }

                // Check if last items are visible to determine if we're at the bottom
                if let lastVisibleIndex = visibility.last?.index {
                    Task { @MainActor in
                        let isNearBottom = lastVisibleIndex >= Double(messages.count - 2)
                        showScrollButton = !isNearBottom

                        // If we scrolled back to bottom, reset the manual scroll flag
                        if isNearBottom && userHasManuallyScrolled {
                            isAtBottom = true
                            // Only reset the manual scroll flag if we're truly at the bottom
                            if lastVisibleIndex >= Double(messages.count - 1) {
                                userHasManuallyScrolled = false
                            }
                        } else if !isNearBottom {
                            isAtBottom = false
                        }
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
                onScrollProxyReady(proxy)
                previousMessageCount = messages.count
                userHasManuallyScrolled = false
                isAtBottom = true
            }
            .onChange(of: messages) { _, newMessages in
                handleScrollOnMessagesChange(proxy, newMessages: newMessages)
            }
            .onChange(of: forceScrollID) {
                scrollToBottomWithoutAnimation(proxy)
                // Reset manual scroll flag when user explicitly requests scroll to bottom
                userHasManuallyScrolled = false
                isAtBottom = true
            }
        }
        .background(Color.clear)
    }

    private func handleScrollOnMessagesChange(_ proxy: ScrollViewProxy, newMessages: [CueChatMessage]) {
        var contentChanged: Bool = false
        if let lastMessage = newMessages.last, let streamingState = lastMessage.streamingState {
            let newLastMessageContent = streamingState.content
            contentChanged = newLastMessageContent != lastMessageContent
            lastMessageContent = newLastMessageContent
        }

        // Initial load case
        if !hasScrolledToBottom && shouldAutoScroll && !newMessages.isEmpty {
            if let lastMessage = newMessages.last {
                scrollToBottomWithoutAnimation(proxy)
                hasScrolledToBottom = true
            }
        }
        // Content update cases
        else if shouldAutoScroll {
            let isNewMessage = newMessages.count > previousMessageCount

            // Always scroll on new messages (not just content updates)
            if isNewMessage {
                if !showScrollButton {
                    scrollToLastMessage(proxy)
                }
                // Reset manual scroll flag when a new message comes in, as that's expected behavior
                if isAtBottom {
                    userHasManuallyScrolled = false
                }
            }
            // For content updates, only scroll if user hasn't manually scrolled away
            else if contentChanged && !userHasManuallyScrolled && isAtBottom {
                scrollToLastMessage(proxy)
            }
        }

        previousMessageCount = newMessages.count
    }

    private func scrollToBottomWithoutAnimation(_ proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func scrollToLastMessage(_ proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
        hasInitialized = true
    }

    private func loadMoreMessages(_ firstVisibleIndex: Double) {
        if firstVisibleIndex < previousFirstVisibleIndex,
           firstVisibleIndex <= 10,
           hasInitialized {
            Task { @MainActor in
                await onLoadMore()
            }
        }
        previousFirstVisibleIndex = firstVisibleIndex
    }
}

struct ViewVisibility: Equatable {
    let index: Double
    let rect: CGRect
}

struct ViewVisibilityKey: PreferenceKey {
    static let defaultValue: [ViewVisibility] = []

    static func reduce(value: inout [ViewVisibility], nextValue: () -> [ViewVisibility]) {
        value.append(contentsOf: nextValue())
    }
}

struct MessageVisibilityTracker: View {
    let index: Int

    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ViewVisibilityKey.self,
                value: [ViewVisibility(index: Double(index), rect: geo.frame(in: .global))]
            )
        }
    }
}
