import SwiftUI

struct SettingsRow<LeadingContent: View>: View {
    let icon: LeadingContent
    let title: String
    let value: String?
    let showChevron: Bool

    init(
        @ViewBuilder icon: () -> LeadingContent,
        title: String,
        value: String? = nil,
        showChevron: Bool = true
    ) {
        self.icon = icon()
        self.title = title
        self.value = value
        self.showChevron = showChevron
    }

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 24, height: 24)
                .foregroundColor(.accentColor)

            Text(title)
                .foregroundColor(.primary)

            Spacer()

            if let value = value {
                Text(value)
                    .foregroundColor(.secondary)
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

extension SettingsRow where LeadingContent == Image {
    init(
        systemName: String,
        title: String,
        value: String? = nil,
        showChevron: Bool = true
    ) {
        self.init(
            icon: { Image(systemName: systemName) },
            title: title,
            value: value,
            showChevron: showChevron
        )
    }
}
