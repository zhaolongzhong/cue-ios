import SwiftUI

struct SendButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(isEnabled ? Color(white: 0.3) : Color.gray.opacity(0.8))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}
