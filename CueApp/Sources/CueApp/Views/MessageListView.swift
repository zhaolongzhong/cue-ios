import SwiftUI
import Combine

struct MessageListView: View {
    let conversationId: String?
    let messages: [CueChatMessage]
    let onLoadMore: (() async -> Void)?
    let onShowMore: ((CueChatMessage) -> Void)?

    @Binding var shouldScrollToBottom: Bool
    @Binding var isLoadingMore: Bool

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var scrollState = ScrollState()
    @State private var currentMessages: [CueChatMessage] = []
    @State private var rawVisibility: [ViewVisibility] = []
    @State private var visibilitySubject = PassthroughSubject<[ViewVisibility], Never>()
    @State private var cancellable: AnyCancellable?
    @State private var expandScrollViewForUserMessage: Bool
    @State private var showScrollButton = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var previousVisibleIndices: [Double] = []
    @State private var loadMoreThreshold = 2
    @State private var preventLoadMoreAfterScroll = false
    @State private var oldFirstVisibleMessageId: String?
    @State private var lastUserMessageId: String?
    @State private var bottomSpacerHeight: CGFloat = 0
    @State private var lastVisibilityUpdate: Date?
    @State private var throttleInterval: TimeInterval = 0.1

    public init(
        conversatonId: String? = nil,
        messages: [CueChatMessage],
        onLoadMore: (() async -> Void)? = nil,
        onShowMore: ((CueChatMessage) -> Void)? = nil,
        shouldScrollToBottom: Binding<Bool>,
        isLoadingMore: Binding<Bool>
    ) {
        self.conversationId = conversatonId
        self.messages = messages
        self.onLoadMore = onLoadMore
        self.onShowMore = onShowMore
        self._shouldScrollToBottom = shouldScrollToBottom
        self._isLoadingMore = isLoadingMore
        self.expandScrollViewForUserMessage = false
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack {
                            Text("debug conversationId: \(conversationId)")
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(message: message)
                                    .id(index)
                                    .background(
                                        MessageVisibilityTracker(index: index)
                                            .frame(height: 1)
                                    )
                            }

                            Spacer()
                                .frame(minHeight: geometry.size.height * (expandScrollViewForUserMessage ? 1 : 0))
                                .id("bottomSpace")

                            Color.clear
                                .frame(height: 1)
                                .id("absoluteBottom")
                        }
                        .padding(.vertical)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .animation(.easeInOut(duration: 0.2), value: messages.count)
                    }
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        self.scrollProxy = scrollProxy
                        scrollToBottom()
                        cancellable = visibilitySubject
                            .removeDuplicates { $0 == $1 }
                            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
                            .sink { debouncedVisibility in
                                handleOnPreferenceChange(visibility: debouncedVisibility)
                            }
                    }
                    .refreshable {
                        await onLoadMore?()
                    }
                    .onChange(of: shouldScrollToBottom) { _, value in
                        handleShouldScrollToBottom(scrollProxy, shouldScrollToBottom: value)
                    }
                    .onChange(of: messages) { oldMessages, newMessages in
                        currentMessages = newMessages
                        handleScrollOnMessagesChange(scrollProxy, oldMessages: oldMessages, newMessages: newMessages)
                        print("inx conversationid: \(conversationId)")

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
                        // Using a Transaction without animation and checking time since last update
                        Task { @MainActor in
                            let now = Date()
                            if lastVisibilityUpdate == nil || now.timeIntervalSince(lastVisibilityUpdate!) > throttleInterval {
                                lastVisibilityUpdate = now
                                withTransaction(Transaction(animation: nil)) {
                                    visibilitySubject.send(visibility)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .center) {
                    if isLoadingMore && !messages.isEmpty {
                        ProgressView()
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .id("loadingIndicator")
                    }

                    Spacer()

                    if showScrollButton {
                        ScrollButton {
                            expandScrollViewForUserMessage = false
                            self.scrollProxy?.scrollTo("absoluteBottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func handleScrollToUserMessage(_ scrollProxy: ScrollViewProxy, newMessages: [CueChatMessage]) {
        expandScrollViewForUserMessage = true
        if let lastUserMessageIndex = newMessages.lastIndex(where: { $0.isUser }) {
            scrollState.isProgrammaticScroll = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                scrollProxy.scrollTo(lastUserMessageIndex, anchor: .top)
            }
        }

        DispatchQueue.main.async {
            scrollState.isProgrammaticScroll = false
        }
    }

    private func handleShouldScrollToBottom(_ scrollProxy: ScrollViewProxy, shouldScrollToBottom: Bool) {
        if shouldScrollToBottom && !messages.isEmpty {
            scrollToBottom()
        }
    }

    private func handleScrollOnMessagesChange(_ proxy: ScrollViewProxy, oldMessages: [CueChatMessage], newMessages: [CueChatMessage]) {
        let hasNewMessage =  newMessages.count > oldMessages.count

        // Handle new user message
        if hasNewMessage, let lastMessage = newMessages.last,
            lastMessage.isUser,
            lastMessage.id != lastUserMessageId {
            lastUserMessageId = lastMessage.id
            handleScrollToUserMessage(proxy, newMessages: newMessages)
            return
        }

        // Handle other messages, either new messages or new content of latest message
        if scrollState.userHasManuallyScrolled && !scrollState.isAtBottom {
            // Check if this is a load more operation (new messages added at the beginning)
            if hasNewMessage {
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
            expandScrollViewForUserMessage = false
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
        if visibility.isEmpty {
            return
        }
        // Filter visibility items by checking if they're in a reasonable viewport range
        let visibleItems = visibility.filter { item in
            // Items with negative max Y or extremely large values are likely out of view
            // This is a simple heuristic that works across platforms
            return item.rect.maxY > 0 && item.rect.minY < 1000
        }

        if visibleItems.isEmpty {
            return
        }

        let currentVisibleIndices = visibleItems.map { $0.index }

        // Detect scroll direction by comparing with previous indices
        if !currentVisibleIndices.isEmpty && !previousVisibleIndices.isEmpty {
            let currentAvg = currentVisibleIndices.reduce(0, +) / Double(currentVisibleIndices.count)
            let prevAvg = previousVisibleIndices.reduce(0, +) / Double(previousVisibleIndices.count)
            scrollState.scrollingUp = currentAvg < prevAvg
        }

        previousVisibleIndices = currentVisibleIndices

        // Check if we should load more messages (only when scrolling manually)
        if !messages.isEmpty && !scrollState.isProgrammaticScroll {
            let minVisibleIndex = currentVisibleIndices.min() ?? Double.infinity

            // If we're seeing messages near the top, trigger load more
            if minVisibleIndex <= Double(loadMoreThreshold) && !isLoadingMore && !preventLoadMoreAfterScroll {
                Task {
                    await loadMoreMessages()
                }
            }
        }

        // Check if last items are visible to determine if we're at the bottom
        let maxIndex = visibility.map { $0.index }.max() ?? 0
        let isNearBottom = maxIndex >= Double(currentMessages.count - 1)
        scrollState.isNearBottom = isNearBottom

        withAnimation {
            showScrollButton = !isNearBottom
        }

        // Handle bottom state tracking
        if isNearBottom {
            scrollState.isAtBottom = true
            if maxIndex >= Double(currentMessages.count - 1) {
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

@MainActor
class ScrollState: ObservableObject {
    @Published var userHasManuallyScrolled = false
    @Published var isProgrammaticScroll = false
    @Published var scrollChangeIsUserInitiated = false
    @Published var isAtBottom = false
    @Published var isNearBottom = false
    @Published var scrollingUp = false

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
