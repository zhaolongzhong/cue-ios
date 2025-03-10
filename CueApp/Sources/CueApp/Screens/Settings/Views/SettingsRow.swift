import SwiftUI

struct SettingsRow: View {
    let icon: Image?
    let title: String
    let value: String?
    let showChevron: Bool
    let trailing: AnyView?
    let showDivider: Bool
    let onTap: (() -> Void)?
    let horizontalPadding: CGFloat

    init(
        systemIcon: String? = nil,
        title: String,
        value: String? = nil,
        showChevron: Bool = false,
        trailing: AnyView? = nil,
        showDivider: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.icon = systemIcon.map { Image(systemName: $0) }
        self.title = title
        self.value = value
        self.showChevron = showChevron
        self.trailing = trailing
        self.showDivider = showDivider
        self.onTap = onTap
        #if os(macOS)
        self.horizontalPadding = 8
        #else
        self.horizontalPadding = 0
        #endif
    }

    var body: some View {
        VStack {
            HStack(spacing: 14) {
                if let icon = icon {
                    #if os(macOS)
                    let size: CGFloat = 12
                    #else
                    let size: CGFloat = 16
                    #endif
                    icon
                        .font(.system(size: size, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: size, height: size)
                }

                Text(title)
                    #if os(iOS)
                    .font(.subheadline)
                    #else
                    .font(.body)
                    #endif
                    .foregroundColor(.primary)

                Spacer()
                if let value = value {
                    Text(value)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if let trailingView = trailing {
                    trailingView
                } else {
                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, horizontalPadding)
            .contentShape(Rectangle())
            .ifLet(onTap) { view, onTap in
                view.onTapGesture {
                    #if os(iOS)
                    HapticManager.shared.impact(style: .light)
                    #endif
                    onTap()
                }
            }
            if showDivider {
                Divider()
                    .padding(.horizontal, horizontalPadding)
            }
        }
    }
}

extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}
