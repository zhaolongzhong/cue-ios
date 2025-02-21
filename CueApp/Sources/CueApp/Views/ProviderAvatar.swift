import SwiftUI

struct ProviderAvatar: View {
    let iconName: String
    var isSystemImage: Bool = false
    var iconSize: CGFloat = 18
    var backgroundColor: Color?
    var strokeColor: Color?

    var body: some View {
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
        .if(backgroundColor != nil) { view in
            view.background(backgroundColor)
                .clipShape(Circle())
        }
        .frame(width: 32, height: 32)
        .if(strokeColor != nil) { view in
            view.overlay(
                Circle()
                    .stroke(strokeColor!, lineWidth: 1)
            )
        }
    }
}
