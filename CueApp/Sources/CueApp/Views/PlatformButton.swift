import SwiftUI

struct PlatformButton<Label: View>: View {
    let action: () async -> Void
    let label: () -> Label
    let isLoading: Bool
    let style: ButtonStyle

    enum ButtonStyle {
        case primary
        case secondary

        var backgroundColor: Color {
            switch self {
            case .primary:
                return AppTheme.Colors.secondaryBackground
            case .secondary:
                return .clear
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary:
                return .primary
            case .secondary:
                return Color.primary.opacity(0.8)
            }
        }

    }

    init(
        action: @escaping () async -> Void,
        isLoading: Bool = false,
        style: ButtonStyle = .primary,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.isLoading = isLoading
        self.style = style
        self.label = label
    }

    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.foregroundColor))
                } else {
                    label()
                }
            }
            #if os(iOS)
           .frame(maxWidth: .infinity)
            #endif
        }
        #if os(iOS)
        .frame(height: 48)
        .padding(.horizontal, 16)
        .background(style.backgroundColor)
        .foregroundColor(style.foregroundColor)
        .cornerRadius(8)
        #else
        .modify { content in
            if style == .primary {
                content
                    .buttonStyle(.borderedProminent)
                    .tint(Color.primary.opacity(0.9))
            } else {
                content
                    .buttonStyle(.plain)
                    .foregroundColor(style.foregroundColor)
            }
        }
        .controlSize(.regular)
        #endif
        .disabled(isLoading)
    }
}

extension View {
    func modify<T: View>(@ViewBuilder _ modification: (Self) -> T) -> T {
        modification(self)
    }
}
