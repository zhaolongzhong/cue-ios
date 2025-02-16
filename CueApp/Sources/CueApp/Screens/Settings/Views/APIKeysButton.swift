import SwiftUI

struct APIKeysButton: View {
    let title: String
    let horizontal: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            #if os(iOS)
            HapticManager.shared.impact(style: .light)
            #endif
            onTap()
        } label: {
            SettingsRow(
                systemName: horizontal ? "key.horizontal" : "key",
                title: title,
                showChevron: true
            )
        }
        .buttonStyle(.plain)
    }
}
