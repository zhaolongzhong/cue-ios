import SwiftUI

struct IconRow: View {
    let title: String
    let action: () -> Void
    let iconName: String
    var isSystemImage: Bool = false
    var iconSize: CGFloat = 18
    var spacing: CGFloat = 12
    var showDivider: Bool = false
    var titleColor: Color = .primary
    var titleFont: Font = .body
    var iconColor: Color = .almostPrimary
    var showBackground: Bool = false
    var backgroundStyle: Color = AppTheme.Colors.controlButtonBackground
    var horizontalPadding: CGFloat = 0

    var body: some View {
        VStack {
            Button {
                withAnimation(.easeOut) {
                    action()
                }
            } label: {
                HStack(spacing: spacing) {
                    Group {
                        if isSystemImage {
                            Image(systemName: iconName)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(iconName, bundle: Bundle.module)
                                .resizable()
                                .scaledToFit()
                        }
                    }
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(iconColor)
                    .if(showBackground) { view in
                        view.background(backgroundStyle)
                            .clipShape(Circle())
                    }
                    .frame(width: 32, height: 32)

                    Text(title)
                        .font(titleFont)
                        .foregroundColor(titleColor)
                    Spacer()
                }
                .padding(.horizontal, horizontalPadding)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)

            if showDivider {
                Divider()
            }
        }
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
