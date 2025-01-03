import SwiftUI

struct AssistantIDView: View {
    let id: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopiedAlert = false

    private var displayId: String {
        guard id.count > 12 else { return id }

        let prefix = String(id.prefix(6))
        let dots = "..."
        let suffix = String(id.suffix(6))

        return "\(prefix)\(dots)\(suffix)"
    }

    var body: some View {

        SettingsRow(
            systemName: "number.circle",
            title: "ID",
            value: displayId,
            trailing: AnyView(
                CopyButton(
                    content: id,
                    isVisible: true
                )
            )
        )
    }
}
