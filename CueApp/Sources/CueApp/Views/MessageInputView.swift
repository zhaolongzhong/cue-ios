import SwiftUI
#if os(iOS)
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
                TextField("Type a message...", text: $inputMessage, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: colorScheme == .light ? 0.95 : 0.15))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.leading)
                    .focused($isFocused)
                SendButton(isEnabled: isMessageValid, action: onSend)
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
#else
import SwiftUI
struct MessageInputView: View {
    @Binding var inputMessage: String
    @FocusState var isFocused: Bool
    let isEnabled: Bool
    let onSend: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var eventMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $inputMessage)
                        .font(.system(size: 15))
                        .frame(minHeight: 50, maxHeight: 200)
                        .fixedSize(horizontal: false, vertical: true)
                        .scrollContentBackground(.hidden)
                    if inputMessage.isEmpty {
                        Text("Type a message...")
                            .padding(.horizontal, 4)
                            .font(.system(size: 15))
                            .foregroundColor(Color(.placeholderTextColor))
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.inputFieldBackground.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(AppTheme.Colors.separator, lineWidth: 0.5)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.leading)
                .focused($isFocused)

                SendButton(isEnabled: isMessageValid, action: onSend)
                    .padding(.trailing, 8)
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.vertical, 8)
        }
        .onAppear {
            setupKeyMonitor()
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }

    private func setupKeyMonitor() {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard isFocused else { return event }

                if event.keyCode == 36 { // Return key
                    print("Return pressed")
                    if event.modifierFlags.contains(.shift) {
                        // Allow new line with Shift+Return
                        return event
                    } else if isMessageValid {
                        onSend()
                        return nil // Consume the event
                    }
                }
                return event
            }
        }

    private var isMessageValid: Bool {
        inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }
}
#endif
