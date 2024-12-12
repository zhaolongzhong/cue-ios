import SwiftUI

struct SettingsRow: View {
    let icon: Image?
    let title: String
    let value: String?
    let showChevron: Bool
    let trailing: AnyView?

    init(
        systemName: String? = nil,
        title: String,
        value: String? = nil,
        showChevron: Bool = false,
        trailing: AnyView? = nil
    ) {
        self.icon = systemName.map { Image(systemName: $0) }
        self.title = title
        self.value = value
        self.showChevron = showChevron
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 14) {
            if let icon = icon {
                icon
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 16, height: 16)
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
                        .foregroundColor(.secondary)
                }
            }

        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}
