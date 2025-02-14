import SwiftUI

struct SectionHeader: View {
    // MARK: - Types
    enum IconType {
        case system(String)
        case custom(String)
    }

    // MARK: - Properties
    let title: String
    var alignment: HorizontalAlignment = .leading
    var fontStyle: Font = .subheadline
    var fontWeight: Font.Weight = .semibold
    var textColor: Color = .secondary
    var spacing: CGFloat = 8
    var padding: EdgeInsets = EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0)
    var trailingIcon: IconType?
    var trailingAction: (() -> Void)?

    // MARK: - Body
    var body: some View {
        HStack(spacing: spacing) {
            Text(title)
                .font(fontStyle)
                .fontWeight(fontWeight)
                .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
                .foregroundColor(textColor)

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
        .padding(padding)
    }

    @ViewBuilder
    private func iconView(for type: IconType) -> some View {
        switch type {
        case .system(let name):
            Image(systemName: name)
                .frame(width: 24, height: 24)
                .foregroundColor(textColor)
        case .custom(let text):
            Text(text)
                .font(.system(size: 18, weight: .light, design: .monospaced))
                .foregroundColor(textColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Preview Provider
struct SectionHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Third Party Providers")
            SectionHeader(
                title: "With System Icon",
                trailingIcon: .system("chevron.right"),
                trailingAction: { print("Tapped trailing icon") }
            )
            SectionHeader(
                title: "With Custom Icon",
                trailingIcon: .custom("A")
            )
            SectionHeader(
                title: "Custom Header",
                alignment: .center,
                fontStyle: .headline,
                fontWeight: .bold,
                textColor: .blue,
                spacing: 12,
                padding: EdgeInsets(top: 16, leading: 8, bottom: 8, trailing: 8),
                trailingIcon: .system("info.circle"),
                trailingAction: { print("Info tapped") }
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
