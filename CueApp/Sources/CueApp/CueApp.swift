import SwiftUI

public struct CueAppView: View {

    public init() {}

    @State private var isMenuOpen: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingFromEdge: Bool = false
    @State private var selectedChat: ChatItem?

    let leftPanelWidth = 300.0

    private let chatItems: [ChatItem] = [
        ChatItem(id: 1, name: "Chat 1"),
        ChatItem(id: 2, name: "Chat 2"),
        ChatItem(id: 3, name: "Chat 3")
    ]

    public var body: some View {
        ZStack {
            VStack {
                // Top Bar with Menu Button
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut) {
                            isMenuOpen.toggle()
                            dragOffset = 0
                        }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .imageScale(.large)
                            .padding()
                    }
                    Spacer()
                }
                .background(Color(.systemBackground))

                Spacer()
                if let item = selectedChat {
                    Text("Selected: \(item.name)")
                        .font(.largeTitle)
                        .transition(.opacity)
                } else {
                    Text("Default View")
                        .font(.largeTitle)
                        .transition(.opacity)
                }
                Spacer()
            }
            .disabled(isMenuOpen)
            .contentShape(Rectangle())
            .onTapGesture {
                if isMenuOpen {
                    withAnimation {
                        isMenuOpen = false
                        dragOffset = 0
                    }
                }
            }

            // Side Menu and Overlay
            GeometryReader { geometry in
                HStack {
                    ChatListView(chatItems: chatItems, selectedChat: $selectedChat, isMenuOpen: $isMenuOpen)
                        .frame(width: leftPanelWidth)
                        .offset(x: isMenuOpen ? dragOffset : -leftPanelWidth + dragOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if isMenuOpen {
                                        dragOffset = min(0, value.translation.width)
                                    } else {
                                        dragOffset = max(0, value.translation.width)
                                    }
                                }
                                .onEnded { value in
                                    withAnimation(.easeInOut) {
                                        if isMenuOpen && value.translation.width < -100 {
                                            isMenuOpen = false
                                        } else if !isMenuOpen && value.translation.width > 100 {
                                            isMenuOpen = true
                                        }
                                        dragOffset = 0
                                    }
                                }
                        )
                    Spacer()
                }
                .frame(width: geometry.size.width)
            }
            .edgesIgnoringSafeArea(.all)
            .allowsHitTesting(isMenuOpen)

            // Edge drag detector
            HStack {
                Color.clear
                    .frame(width: 20)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isMenuOpen {
                                    isDraggingFromEdge = true
                                    dragOffset = max(0, min(leftPanelWidth, value.translation.width))
                                }
                            }
                            .onEnded { value in
                                withAnimation(.easeInOut) {
                                    if value.translation.width > 50 {
                                        isMenuOpen = true
                                    }
                                    dragOffset = 0
                                    isDraggingFromEdge = false
                                }
                            }
                    )
                Spacer()
            }
        }
        .animation(.easeInOut, value: isMenuOpen)
    }
}

#Preview {
    CueAppView()
        .preferredColorScheme(.dark)
}
