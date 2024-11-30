import SwiftUI

struct MessageInputView: View {
    @Binding var inputMessage: String
    @FocusState var isFocused: Bool
    let isEnabled: Bool
    let onSend: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                TextField("Type a message...", text: $inputMessage)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: colorScheme == .light ? 0.95 : 0.15))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.leading)
                    .focused($isFocused)

                Button(action: onSend) {
                    Circle()
                        .fill(isMessageValid ? Color(white: 0.3) : Color.gray.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        )
                }
                .disabled(!isMessageValid)
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            .padding(.vertical, 8)
        }
        .background(AppTheme.Colors.background)
    }

    private var isMessageValid: Bool {
        inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }
}

public struct MessageInputViewAudio: View {
    @Binding var inputMessage: String
    @FocusState var isFocused: Bool
    let isEnabled: Bool
    let isRecording: Bool
    let onSend: () -> Void
    let onAudioButtonPressed: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        HStack(spacing: 12) {
            HStack {
                TextField("Chat", text: $inputMessage, onCommit: { onSend() })
                    .frame(height: 40)
                    .submitLabel(.send)

                if !inputMessage.isEmpty {
                    Button(action: onSend) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.white, .blue)
                    }
                }

                Button(action: onAudioButtonPressed) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.leading)
            .padding(.trailing, 6)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary, lineWidth: 1))
        }
        .padding()
    }
}
