import SwiftUI
import Dependencies

struct RichTextField: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @Environment(\.colorScheme) private var colorScheme
    @FocusState.Binding var isFocused: Bool
    @State private var isTextFieldVisible = false
    @State private var inputMessage: String

    // The ViewModel state is passed by reference, not copied locally
    private let richTextFieldState: RichTextFieldState
    private let richTextFieldDelegate: RichTextFieldDelegate

    init(
        isFocused: FocusState<Bool>.Binding,
        richTextFieldState: RichTextFieldState,
        richTextFieldDelegate: RichTextFieldDelegate
    ) {
        self._isFocused = isFocused
        self.richTextFieldState = richTextFieldState
        self._inputMessage = State(initialValue: richTextFieldState.inputMessage)
        self.richTextFieldDelegate = richTextFieldDelegate
    }

    var body: some View {
        VStack {
            if !richTextFieldState.attachments.isEmpty {
                AttachmentsListView(attachments: richTextFieldState.attachments, onRemove: { index in
                    richTextFieldDelegate.onRemoveAttachment(at: index)
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
                    .onChange(of: inputMessage) { newValue in
                        // Delegate the change to the ViewModel
                        richTextFieldDelegate.onUpdateInputMessage(newValue)
                    }
                    .onSubmit {
                        if richTextFieldState.isMessageValid && !richTextFieldState.isRunning {
                            richTextFieldDelegate.onClearAttachments()
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
                .fill(AppTheme.Colors.secondaryBackground.opacity(0.1))
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
        .padding(.horizontal)
        .padding(.bottom)
        .onChange(of: isFocused) { _, newValue in
            if !newValue {
                checkAndUpdateTextFieldVisibility()
            }
        }
        .onChange(of: richTextFieldState.inputMessage) { _, newValue in
            // Keep local inputMessage in sync with ViewModel state
            if inputMessage != newValue {
                inputMessage = newValue
            }

            if !newValue.isEmpty && !isTextFieldVisible {
                isTextFieldVisible = true
            }
        }
        .onAppear {
            isTextFieldVisible = richTextFieldState.isTextFieldVisible
        }
    }

    private var controlButtons: some View {
        HStack {
            if featureFlags.enableMediaOptions {
                AttachmentPickerMenu { attachment in
                    richTextFieldDelegate.onAddAttachment(attachment)
                }
            }
            Text("Type a message ...")
                .foregroundColor(.secondary.opacity(0.6))
                .opacity(isTextFieldVisible ? 0 : 1)
            Spacer()
            if richTextFieldState.availableCapabilities.count > 0 {
                ToolSelectionMenu(
                    availableCapabilities: richTextFieldState.availableCapabilities,
                    selectedCapabilities: richTextFieldState.selectedCapabilities,
                    onCapabilitiesSelected: { capabilities in
                        richTextFieldDelegate.onUpdateSelectedCapabilities(capabilities)
                    }
                )
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
                isEnabled: richTextFieldState.isMessageValid,
                isRunning: richTextFieldState.isRunning,
                onSend: {
                    print("inx send richTextFieldState: \(richTextFieldState.conversationId), message: \(richTextFieldState.inputMessage)")
                    richTextFieldDelegate.onClearAttachments()
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
        if richTextFieldState.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            isTextFieldVisible = false
        }
    }
}

