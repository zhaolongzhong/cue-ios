import SwiftUI

struct MessagesListView: View {
    let messages: [MessageModel]
    let shouldAutoScroll: Bool
    let onScrollProxyReady: (ScrollViewProxy) -> Void
    let onLoadMore: () async -> Void
    let onShowMore: (MessageModel?) -> Void

    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasInitialized = false
    @State private var showScrollButton = false
    @State private var previousMessageCount = 0

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
                onLoadMore: onLoadMore,
                onShowMore: onShowMore
            )
            .refreshable {
                await onLoadMore()
            }
            .focusable(false)

            if showScrollButton {
                ScrollButton(isVisible: showScrollButton) {
                    scrollToBottom()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(0)
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
}

struct MessagesList: View {
    let messages: [MessageModel]
    @Binding var scrollProxy: ScrollViewProxy?
    @Binding var showScrollButton: Bool
    let shouldAutoScroll: Bool
    let onScrollProxyReady: (ScrollViewProxy) -> Void
    @Binding var hasInitialized: Bool
    @Binding var previousMessageCount: Int
    let onLoadMore: () async -> Void
    let onShowMore: (MessageModel?) -> Void
    @State var previousFirstVisibleIndex: Double = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(
                            message: message,
                            role: message.author.role,
                            content: message.getText(),
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
                if shouldAutoScroll {
                    scrollToLastMessage(proxy)
                }
                previousMessageCount = messages.count
            }
            .onChange(of: messages) { _, newMessages in
                if shouldAutoScroll && newMessages.count > previousMessageCount {
                    if !showScrollButton {
                        scrollToLastMessage(proxy)
                    }
                }
                previousMessageCount = newMessages.count
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
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        if isVisible {
            Button(action: action) {
                Circle()
                    .fill(AppTheme.Colors.tertiaryBackground)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Image(systemName: "arrow.down")
                            .font(.system(size: iconSize, weight: .regular))
                            .foregroundColor(AppTheme.Colors.primaryText)
                    )
                    .shadow(radius: 2)
            }
            .buttonStyle(.plain)
            .padding(buttonPadding)
            .transition(.opacity)
        }
    }

    private var buttonSize: CGFloat {
        #if os(iOS)
        44
        #else
        32
        #endif
    }

    private var iconSize: CGFloat {
        #if os(iOS)
        16
        #else
        12
        #endif
    }

    private var buttonPadding: CGFloat {
        #if os(iOS)
        16
        #else
        8
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
