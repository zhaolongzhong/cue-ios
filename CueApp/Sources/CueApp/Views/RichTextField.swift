import SwiftUI
import Dependencies

struct RichTextField: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @Environment(\.colorScheme) private var colorScheme
    @Binding var inputMessage: String
    @FocusState.Binding var isFocused: Bool
    @State private var isTextFieldVisible = false
    @ObservedObject var richTextFieldState: RichTextFieldState
    private let richTextFieldDelegate: RichTextFieldDelegate

    init(
        inputMessage: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        richTextFieldState: RichTextFieldState,
        richTextFieldDelegate: RichTextFieldDelegate
    ) {
        self._inputMessage = inputMessage
        self._isFocused = isFocused
        self.richTextFieldState = richTextFieldState
        self.richTextFieldDelegate = richTextFieldDelegate
    }

    var body: some View {
        VStack {
            if !richTextFieldState.attachments.isEmpty {
                AttachmentsListView(attachments: richTextFieldState.attachments, onRemove: { index in
                    richTextFieldState.attachments.remove(at: index)
                })
            }

            if isTextFieldVisible {
                TextField("Type a message...", text: $inputMessage, axis: .vertical)
                    .scrollContentBackground(.hidden)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .background(.clear)
                    .onSubmit {
                        if isMessageValid && !richTextFieldState.isRunning {
                            richTextFieldState.attachments.removeAll()
                            richTextFieldDelegate.onSend()
                        }
                    }
                    .submitLabel(.return)

            }
            controlButtons
        }
        .padding(.all, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.secondaryBackground.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppTheme.Colors.separator, lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            Group {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.Colors.separator, lineWidth: 1)
                }
            }
        )
        .onChange(of: isFocused) { _, newValue in
            if !newValue {
                checkAndUpdateTextFieldVisibility()
            }
        }
        .onChange(of: inputMessage) { _, newValue in
            if !newValue.isEmpty && !isTextFieldVisible {
                isTextFieldVisible = true
            }
        }
        .padding()
    }

    private var controlButtons: some View {
        HStack {
            if featureFlags.enableMediaOptions {
                AttachmentPickerMenu { attachment in
                    richTextFieldState.attachments.append(attachment)
                    richTextFieldDelegate.onPickAttachment(attachment)
                }
            }
            Text("Type a message ...")
                .foregroundColor(.secondary.opacity(0.6))
                .opacity(isTextFieldVisible ? 0 : 1)
            Spacer()
            if richTextFieldState.toolCount != 0 {
                ToolButton(count: richTextFieldState.toolCount, action: {
                    richTextFieldDelegate.onShowTools()
                    checkAndUpdateTextFieldVisibility()
                })
            }
            if richTextFieldState.showAXApp {
                #if os(macOS)
                AXAppSelectionMenu(onStartAXApp: richTextFieldDelegate.onShowAXApp)
                #endif
            }
            if richTextFieldState.showVoiceChat {
                VoiceChatButton(action: {
                    richTextFieldDelegate.onOpenVoiceChat()
                    checkAndUpdateTextFieldVisibility()
                })
            }
            SendButton(
                isEnabled: isMessageValid,
                isRunning: richTextFieldState.isRunning,
                onSend: {
                    richTextFieldState.attachments.removeAll()
                    richTextFieldDelegate.onSend()
                },
                onStop: richTextFieldDelegate.onStop
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showTextField()
        }
    }

    private func showTextField() {
        isTextFieldVisible = true
        isFocused = true
    }

    private func checkAndUpdateTextFieldVisibility() {
        if inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isTextFieldVisible = false
        }
    }

    private var isMessageValid: Bool {
        inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1 || !richTextFieldState.attachments.isEmpty
    }
}
