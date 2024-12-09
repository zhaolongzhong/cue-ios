import SwiftUI

struct SettingsRow: View {
    let icon: Image?
    let title: String
    let value: String?
    let showChevron: Bool

    init(
        systemName: String? = nil,
        title: String,
        value: String? = nil,
        showChevron: Bool = true
    ) {
        self.icon = systemName.map { Image(systemName: $0) }
        self.title = title
        self.value = value
        self.showChevron = showChevron
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                icon
                    .frame(width: 24, height: 24)
                    .foregroundColor(.primary)
            }

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
        #if os(iOS)
        .padding(.horizontal, 0)
        #else
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        #endif
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .listRowInsets(EdgeInsets())
    }
}
