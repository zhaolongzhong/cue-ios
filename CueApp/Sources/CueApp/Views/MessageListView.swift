import SwiftUI
import Combine

struct MessageListView: View {
    let conversationId: String?
    let messages: [CueChatMessage]
    let onLoadMore: (() async -> Void)?
    let onShowMore: ((CueChatMessage) -> Void)

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
    @State private var initialScrollAttempted = false
    @State private var viewAppeared = false

    public init(
        conversatonId: String? = nil,
        messages: [CueChatMessage],
        onLoadMore: (() async -> Void)? = nil,
        onShowMore: @escaping (CueChatMessage) -> Void,
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
                ScrollViewReader { proxy in
                    ScrollView {
                        Color.clear.frame(height: 0).onAppear {
                            self.scrollProxy = proxy
                        }

                        LazyVStack(spacing: 8) {
                            Color.clear.frame(height: 1).id("topAnchor")

                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(message: message, onShowMore: onShowMore)
                                    .id(index)
                                    .background(
                                        MessageVisibilityTracker(index: index)
                                            .frame(height: 1)
                                    )
                            }

                            Color.clear
                                #if os(macOS)
                                .frame(height: geometry.size.height * 0.1)
                                #else
                                .frame(height: geometry.size.height * 0.1)
                                #endif
                                .id("bottomAnchor")
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.2), value: messages.count)
                    }
                    .scrollContentBackground(.hidden)
                    #if os(iOS)
                    .simultaneousGesture(DragGesture().onChanged { _ in
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                      to: nil, from: nil, for: nil)
                    })
                    #endif
                    .onAppear {
                        AppLog.log.debug("onAppear MessageListView, messages: \(messages.count)")
                        viewAppeared = true
                        // Wait for layout to complete before scrolling
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            attemptInitialScroll()
                        }

                        // Setup the visibility observer
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
                        if value {
                            attemptScrollToBottom(withRetries: true)
                        }
                    }
                    .onChange(of: messages) { oldMessages, newMessages in
                        currentMessages = newMessages

                        if !initialScrollAttempted && !newMessages.isEmpty && viewAppeared {
                            initialScrollAttempted = true
                            attemptScrollToBottom(withRetries: true)
                        } else {
                            handleScrollOnMessagesChange(proxy, oldMessages: oldMessages, newMessages: newMessages)
                        }
                    }
                    .onChange(of: isLoadingMore) { wasLoading, isNowLoading in
                        if wasLoading && !isNowLoading {
                            // When loading completes, reset the prevention flag after a short delay to ensure
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
                            attemptScrollToBottom(withRetries: false)
                        }
                    }
                }
            }
        }
    }

    private func attemptInitialScroll() {
        if !messages.isEmpty {
            initialScrollAttempted = true
            attemptScrollToBottom(withRetries: true)
        }
    }

    @State private var pendingScrollWorkItems: [DispatchWorkItem] = []

    private func attemptScrollToBottom(withRetries: Bool) {
        pendingScrollWorkItems.forEach { $0.cancel() }
        pendingScrollWorkItems.removeAll()

        // If we're already at the bottom, skip further scrolling
        if scrollState.isAtBottom {
            showScrollButton = false
            return
        }

        // First attempt
        scrollToBottom()
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
            attemptScrollToBottom(withRetries: true)
        }
    }

    private func handleScrollOnMessagesChange(_ proxy: ScrollViewProxy, oldMessages: [CueChatMessage], newMessages: [CueChatMessage]) {
        let hasNewMessage = newMessages.count > oldMessages.count

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
                   newMessages.firstIndex(where: { $0.id == oldFirstMessageId }) != nil {

                    // Set flag to prevent load more triggering when we adjust scroll
                    preventLoadMoreAfterScroll = true

                    // Maintain scroll position
                    // scrollState.isProgrammaticScroll = true
                    // proxy.scrollTo(newIndex, anchor: .top)

                    // Reset programmatic scroll flag after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollState.isProgrammaticScroll = false
                    }
                }
            }
            return
        }

        // If new messages arrived and user hasn't scrolled manually, scroll to bottom
        if hasNewMessage && !scrollState.userHasManuallyScrolled {
            attemptScrollToBottom(withRetries: true)
        }
    }

    private func scrollToBottom(animate: Bool = false, force: Bool = false) {
        if self.messages.isEmpty {
            return
        }

        guard let proxy = scrollProxy else {
            return
        }

        if scrollState.isAtBottom && !force {
            return
        }

        scrollState.isProgrammaticScroll = true

        if animate {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                proxy.scrollTo("bottomAnchor", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottomAnchor", anchor: .bottom)
        }

        DispatchQueue.main.async {
            self.shouldScrollToBottom = false
            self.expandScrollViewForUserMessage = false
            self.scrollState.isAtBottom = true
            self.scrollState.isProgrammaticScroll = false
            self.scrollState.userHasManuallyScrolled = false
        }
    }

    @MainActor
    private func loadMoreMessages() async {
        guard !isLoadingMore, let onLoadMore = onLoadMore, !preventLoadMoreAfterScroll else {
            return
        }

        oldFirstVisibleMessageId = messages.first?.id
        preventLoadMoreAfterScroll = true

        await onLoadMore()
    }

    @MainActor
    private func handleOnPreferenceChange(visibility: [ViewVisibility]) {
        if visibility.isEmpty {
            return
        }
        let visibleItems = visibility.filter { item in
            return item.rect.maxY > 0 && item.rect.minY < 1000
        }

        if visibleItems.isEmpty {
            return
        }

        let currentVisibleIndices = visibleItems.map { $0.index }

        if !currentVisibleIndices.isEmpty && !previousVisibleIndices.isEmpty {
            let currentAvg = currentVisibleIndices.reduce(0, +) / Double(currentVisibleIndices.count)
            let prevAvg = previousVisibleIndices.reduce(0, +) / Double(previousVisibleIndices.count)
            scrollState.scrollingUp = currentAvg < prevAvg
        }

        previousVisibleIndices = currentVisibleIndices

        if !messages.isEmpty && !scrollState.isProgrammaticScroll {
            let minVisibleIndex = currentVisibleIndices.min() ?? Double.infinity

            if minVisibleIndex <= Double(loadMoreThreshold) && !isLoadingMore && !preventLoadMoreAfterScroll {
                Task {
                    await loadMoreMessages()
                }
            }
        }

        let maxIndex = visibility.map { $0.index }.max() ?? 0
        let isNearBottom = maxIndex >= Double(currentMessages.count - 1)

        scrollState.isNearBottom = isNearBottom

        if !isNearBottom && !scrollState.isProgrammaticScroll {
            scrollState.userHasManuallyScrolled = true
        }

        withAnimation {
            showScrollButton = !isNearBottom
        }

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
