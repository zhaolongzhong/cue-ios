import SwiftUI

struct SendButton: View {
    let isEnabled: Bool
    let isRunning: Bool
    let onSend: () -> Void
    let onStop: (() -> Void)?

    public init(
        isEnabled: Bool = true,
        isRunning: Bool = false,
        onSend: @escaping () -> Void,
        onStop: (() -> Void)? = nil
    ) {
        self.isEnabled = isEnabled
        self.isRunning = isRunning
        self.onStop = onStop
        self.onSend = onSend
    }

    var body: some View {
        Group {
            if isRunning, let onStop = onStop {
                Button(action: onStop) {
                    Circle()
                        .fill(isEnabled ? Color.primary : Color.primary.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.primary)
                                .colorInvert()
                        )
                }
                .buttonStyle(.borderless)
            } else {
                Button(action: onSend) {
                    Circle()
                        .fill(isEnabled ? Color.primary : Color.primary.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.primary)
                                .colorInvert()
                        )
                }
                .disabled(!isEnabled)
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }
}
