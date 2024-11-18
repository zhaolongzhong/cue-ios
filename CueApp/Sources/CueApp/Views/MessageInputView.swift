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
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(white: colorScheme == .light ? 0.95 : 0.15))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.leading)
                    .focused($isFocused)

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(
                            inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .secondary
                            : .accentColor
                        )
                }
                .disabled(inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
        .background(AppTheme.Colors.background)
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
