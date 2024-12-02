import SwiftUI

struct MessagesListView: View {
    let messages: [MessageModel]
    let shouldAutoScroll: Bool

    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasInitialized = false
    @State private var isUserScrolling = false
    @State private var lastContentOffset: CGFloat = 0
    @State private var isScrolling = false

    // Add minimum height for content
    private let minimumContentHeight: CGFloat = 600

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        // Use GeometryReader for more precise spacing
                        GeometryReader { contentGeometry in
                            Color.clear.frame(height: max(0, contentGeometry.frame(in: .global).height))
                        }

                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.bottom, 10)
                    .padding(.top, 8)
                    // Use geometry reader's height instead of UIScreen
                    .frame(maxWidth: .infinity, minHeight: max(geometry.size.height, minimumContentHeight))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.Colors.background)
                #if os(macOS)
                .background(
                    GeometryReader { geometry -> Color in
                        DispatchQueue.main.async {
                            let currentOffset = geometry.frame(in: .global).minY
                            if abs(currentOffset - lastContentOffset) > 0.1 {
                                isScrolling = true
                                lastContentOffset = currentOffset
                            } else {
                                isScrolling = false
                            }
                        }
                        return Color.clear
                    }
                )
                .scrollDisabled(isScrolling && !hasInitialized)
                #endif
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

                    if shouldAutoScroll && !hasInitialized && !messages.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            performInitialScroll()
                        }
                    }
                }
                .onChange(of: messages) { oldMessages, newMessages in
                    guard !newMessages.isEmpty else { return }

                    if oldMessages.isEmpty && !newMessages.isEmpty && shouldAutoScroll && !hasInitialized {
                        performInitialScroll()
                        return
                    }

                    let hasNewMessages = newMessages.count > oldMessages.count
                    let isAtBottom = shouldAutoScroll && (hasInitialized || hasNewMessages)

                    if isAtBottom && !isUserScrolling {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            scrollProxy?.scrollTo(newMessages.last?.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func performInitialScroll() {
        withAnimation(.easeOut(duration: 0.3)) {
            scrollProxy?.scrollTo(messages.last?.id, anchor: .bottom)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
