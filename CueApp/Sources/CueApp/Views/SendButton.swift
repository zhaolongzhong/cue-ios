import SwiftUI

struct SendButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(isEnabled ? Color.primary : Color.primary.opacity(0.8))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.primary)
                        .colorInvert()
                )
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}
