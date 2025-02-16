import SwiftUI

struct ToolButtonView: View {
    @Environment(\.colorScheme) var colorScheme
    let message: CueChatMessage

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("</>")
                .font(.system(size: 18))
                .foregroundColor(.primary.opacity(0.6))
                .frame(width: 60, height: 60)
                .background(.secondary.opacity(0.1))

            Divider()
                .frame(height: 60)
                .background(.secondary.opacity(0.2))

            VStack(alignment: .leading, spacing: 2) {
                Text("Use tool")
                    .font(.headline)
                    .foregroundColor(.primary.opacity(0.6))
                Text("Click to open details")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.leading, 10)

            Spacer()
        }
        .padding(.vertical, 10)
        .frame(height: 60)
        .frame(maxWidth: 320)
        .background(.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
