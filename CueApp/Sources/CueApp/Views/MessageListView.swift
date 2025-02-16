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

    private func scrollToBottom() {
        guard let lastMessage = messages.last else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
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
            .onPreferenceChange(ViewVisibilityKey.self) { visibility in
                if let firstVisibleIndex = visibility.first?.index {
                    #if os(macOS)
                    Task { @MainActor in
                        loadMoreMessages(firstVisibleIndex)
                    }
                    #endif
                }

                if let lastVisibleIndex = visibility.last?.index {
                    Task { @MainActor in
                        showScrollButton = lastVisibleIndex < Double(messages.count - 3)
                    }
                }
            }
            .onAppear {
                scrollProxy = proxy
                onScrollProxyReady(proxy)
                previousMessageCount = messages.count
            }
            .onChange(of: messages) { _, newMessages in
                if !hasScrolledToBottom && shouldAutoScroll && !newMessages.isEmpty {
                    if let lastMessage = newMessages.last {
                        // Scroll without animation for initial load
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        hasScrolledToBottom = true
                    }
                } else if shouldAutoScroll && newMessages.count > previousMessageCount {
                    if !showScrollButton {
                        scrollToLastMessage(proxy)
                    }
                }
                previousMessageCount = newMessages.count
            }
            .onChange(of: forceScrollID) {
                guard let lastMessage = messages.last else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
        .background(Color.clear)
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

struct ScrollButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(AppTheme.Colors.alternateInputBackground)
                .frame(width: platformButtonSize, height: platformButtonSize)
                .overlay(
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.Colors.primaryText)
                )
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .padding(16)
        .transition(.opacity)
    }

    private var platformButtonSize: CGFloat {
        #if os(iOS)
        36
        #else
        32
        #endif
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
