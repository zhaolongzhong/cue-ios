import SwiftUI

struct MessageListView: View {
    let messages: [CueChatMessage]
    let onLoadMore: (() async -> Void)?
    let onShowMore: ((CueChatMessage) -> Void)?

    @Binding var shouldScrollToUserMessage: Bool
    @Binding var shouldScrollToBottom: Bool
    @Binding var isLoadingMore: Bool

    @State private var expandScrollViewForUserMessage: Bool = false
    @State private var showScrollButton = false
    @State private var scrollProxy: ScrollViewProxy?
    @StateObject private var scrollState = ScrollState()
    @State private var previousVisibleIndices: [Double] = []
    @State private var loadMoreThreshold = 2
    @State private var preventLoadMoreAfterScroll = false
    @State private var oldFirstVisibleMessageId: String?

    public init(
        messages: [CueChatMessage],
        onLoadMore: (() async -> Void)? = nil,
        onShowMore: ((CueChatMessage) -> Void)? = nil,
        shouldScrollToUserMessage: Binding<Bool>,
        shouldScrollToBottom: Binding<Bool>,
        isLoadingMore: Binding<Bool>
    ) {
        self.messages = messages
        self.onLoadMore = onLoadMore
        self.onShowMore = onShowMore
        self._shouldScrollToUserMessage = shouldScrollToUserMessage
        self._shouldScrollToBottom = shouldScrollToBottom
        self._isLoadingMore = isLoadingMore
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(message: message)
                                    .id(index)
                                    .background(
                                        MessageVisibilityTracker(index: index)
                                            .frame(height: 1)
                                    )
                            }
                            if !messages.isEmpty {
                                Spacer()
                                    .frame(minHeight: geometry.size.height * (            expandScrollViewForUserMessage ? 0.75 : 0))
                                    .id("bottomSpace")
                            }
                            Color.clear
                                .frame(height: 1)
                                .id("absoluteBottom")
                        }
                        .padding(.vertical)
                        .frame(minHeight: geometry.size.height)
                        .animation(.easeInOut(duration: 0.2), value: messages.count)
                    }
                    .onAppear {
                        self.scrollProxy = scrollProxy
                        scrollToBottom()
                    }
                    .refreshable {
                        await onLoadMore?()
                    }
                    .onChange(of: shouldScrollToUserMessage) { _, value in
                        handleScrollToUserMessage(scrollProxy, shouldScrollToUserMessage: value)
                    }
                    .onChange(of: shouldScrollToBottom) { _, value in
                        handleShouldScrollToBottom(scrollProxy, shouldScrollToBottom: value)
                    }
                    .onChange(of: messages) { oldMessages, newMessages in
                        handleScrollOnMessagesChange(scrollProxy, oldMessages: oldMessages, newMessages: newMessages)
                    }
                    .onChange(of: isLoadingMore) { wasLoading, isNowLoading in
                        // When loading completes
                        if wasLoading && !isNowLoading {
                            // Reset the prevention flag after a short delay to ensure
                            // scroll position adjustments have completed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                preventLoadMoreAfterScroll = false
                            }
                        }
                    }
                    #if os(macOS)
                    .onHover { isHovering in
                        if isHovering {
                            NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { event in
                                // Only register if not a programmatic scroll
                                if !scrollState.isProgrammaticScroll {
                                    scrollState.userHasManuallyScrolled = true
                                }
                                return event
                            }
                        }
                    }
                    #endif
                    .onPreferenceChange(ViewVisibilityKey.self) { visibility in
                        Task { @MainActor in
                            handleOnPreferenceChange(visibility: visibility)
                        }
                    }
                }

                VStack {
                    if isLoadingMore && !messages.isEmpty {
                        ProgressView()
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .id("loadingIndicator")
                    }

                    Spacer()

                    if showScrollButton {
                        ScrollButton {
                            self.scrollProxy?.scrollTo("absoluteBottom", anchor: .bottom)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }

    private func handleScrollToUserMessage(_ scrollProxy: ScrollViewProxy, shouldScrollToUserMessage: Bool) {
        if shouldScrollToUserMessage && self.messages.count >= 2 {
            expandScrollViewForUserMessage = true
            if let lastUserMessageIndex = self.messages.lastIndex(where: { $0.isUser }) {
                scrollState.isProgrammaticScroll = true
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    scrollProxy.scrollTo(lastUserMessageIndex, anchor: .top)
                }
            }

            DispatchQueue.main.async {
                self.shouldScrollToUserMessage = false
                scrollState.isProgrammaticScroll = false
            }
        }
    }

    private func handleShouldScrollToBottom(_ scrollProxy: ScrollViewProxy, shouldScrollToBottom: Bool) {
        if shouldScrollToBottom && !messages.isEmpty {
            scrollToBottom()
        }
    }

    private func handleScrollOnMessagesChange(_ proxy: ScrollViewProxy, oldMessages: [CueChatMessage], newMessages: [CueChatMessage]) {
        if scrollState.userHasManuallyScrolled && !scrollState.isAtBottom {
            // Check if this is a load more operation (new messages added at the beginning)
            if newMessages.count > oldMessages.count && oldMessages.count > 0 {
                // Check if first message of old messages is still in new messages
                if let oldFirstMessageId = oldMessages.first?.id,
                   let newIndex = newMessages.firstIndex(where: { $0.id == oldFirstMessageId }) {

                    // Set flag to prevent load more triggering when we adjust scroll
                    preventLoadMoreAfterScroll = true

                    // Maintain scroll position
                    scrollState.isProgrammaticScroll = true
                    proxy.scrollTo(newIndex, anchor: .top)

                    // Reset programmatic scroll flag after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollState.isProgrammaticScroll = false
                    }
                }
            }
            return
        }
    }

    private func scrollToBottom(animate: Bool = false) {
        scrollState.isProgrammaticScroll = true

        if animate {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                scrollProxy?.scrollTo("absoluteBottom", anchor: .bottom)
            }
        } else {
            scrollProxy?.scrollTo("absoluteBottom", anchor: .bottom)
        }

        DispatchQueue.main.async {
            self.shouldScrollToBottom = false
            scrollState.isAtBottom = true
            scrollState.isProgrammaticScroll = false
            scrollState.userHasManuallyScrolled = false
        }
    }

    @MainActor
    private func loadMoreMessages() async {
        guard !isLoadingMore, let onLoadMore = onLoadMore, !preventLoadMoreAfterScroll else {
            return
        }

        // Store the current first message ID before loading more
        oldFirstVisibleMessageId = messages.first?.id

        // Temporarily disable further load more triggers
        preventLoadMoreAfterScroll = true

        await onLoadMore()
    }

    @MainActor
    private func handleOnPreferenceChange(visibility: [ViewVisibility]) {
        let currentVisibleIndices = visibility.map { $0.index }

        // Detect scroll direction by comparing with previous indices
        if !currentVisibleIndices.isEmpty && !previousVisibleIndices.isEmpty {
            let currentAvg = currentVisibleIndices.reduce(0, +) / Double(currentVisibleIndices.count)
            let prevAvg = previousVisibleIndices.reduce(0, +) / Double(previousVisibleIndices.count)

            let scrollingUp = currentAvg < prevAvg

            if scrollingUp && !currentVisibleIndices.isEmpty {
                // Get the highest visible index (closest to bottom of content)
                if let highestVisibleIndex = currentVisibleIndices.max(),
                   // Check if the bottom of content is not visible
                   highestVisibleIndex < Double(messages.count - 2) {
                    showScrollButton = true
                }
            }
        }

        previousVisibleIndices = currentVisibleIndices

        // Check if we should load more messages (only when scrolling manually)
        if !visibility.isEmpty && !messages.isEmpty && !scrollState.isProgrammaticScroll {
            let minVisibleIndex = visibility.map { $0.index }.min() ?? Double.infinity

            // If we're seeing messages near the top, trigger load more
            if minVisibleIndex <= Double(loadMoreThreshold) && !isLoadingMore && !preventLoadMoreAfterScroll {
                Task {
                    await loadMoreMessages()
                }
            }
        }

        // Check if last items are visible to determine if we're at the bottom
        if !visibility.isEmpty {
            let maxIndex = visibility.map { $0.index }.max() ?? 0

            // Determine if we're at the bottom
            let isNearBottom = maxIndex >= Double(messages.count - 2)

            // Show button whenever we're not at the bottom
            showScrollButton = !isNearBottom

            // If we're significantly away from the bottom (scrolled up a lot)
            if maxIndex < Double(messages.count - 3) {
                showScrollButton = true
            }

            // Handle bottom state tracking
            if isNearBottom {
                scrollState.isAtBottom = true
                if maxIndex >= Double(messages.count - 1) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if scrollState.isAtBottom {
                            scrollState.userHasManuallyScrolled = false
                        }
                    }
                }
            } else {
                scrollState.isAtBottom = false
            }
        }
    }
}

@MainActor
class ScrollState: ObservableObject {
    @Published var userHasManuallyScrolled = false
    @Published var isProgrammaticScroll = false
    @Published var scrollChangeIsUserInitiated = false
    @Published var isAtBottom = false

    // Timer to detect manual scrolling
    var scrollTimer: Timer?

    func resetTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    func startDetection() {
        resetTimer()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.scrollChangeIsUserInitiated = true
            }
        }
    }
}
