import SwiftUI

struct SidebarRowButton: View {
    enum IconType {
        case system(String)
        case custom(String)
    }

    let title: String
    let icon: IconType?
    let action: (() -> Void)?
    let trailingIcon: IconType?
    let trailingAction: (() -> Void)?
    let spacing: CGFloat

    init(
        title: String,
        icon: IconType? = nil,
        trailingIcon: IconType? = nil,
        action: (() -> Void)? = nil,
        trailingAction: (() -> Void)? = nil,
        spacing: CGFloat = 12
    ) {
        self.title = title
        self.icon = icon
        self.trailingIcon = trailingIcon
        self.action = action
        self.trailingAction = trailingAction
        self.spacing = spacing
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    iconView(for: icon)
                        .frame(width: 32, height: 32)
                }
                Text(title)
                    .padding(.leading, 2)
                Spacer()
                if let trailingIcon {
                    if let trailingAction {
                        Button(action: trailingAction) {
                            iconView(for: trailingIcon)
                        }
                        .buttonStyle(.plain)
                    } else {
                        iconView(for: trailingIcon)
                    }
                }
            }
            .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func iconView(for type: IconType) -> some View {
        switch type {
        case .system(let name):
            Image(systemName: name)
                .frame(width: 24, height: 24)
        case .custom(let text):
            Text(text)
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .strokeBorder(AppTheme.Colors.separator, lineWidth: 1)
                )
        }
    }
}
