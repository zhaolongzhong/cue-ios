import SwiftUI

struct HoverButton<Content: View>: View {
    @State private var isHovering = false
    let content: Content
    var height: CGFloat = 24
    var horizontalPadding: CGFloat = 6

    init(height: CGFloat = 24,
         horizontalPadding: CGFloat = 0,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.height = height
        self.horizontalPadding = horizontalPadding
    }

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .frame(minWidth: height)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppTheme.Colors.textColor.opacity(0.1))
                    .opacity(isHovering ? 1 : 0)
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}
