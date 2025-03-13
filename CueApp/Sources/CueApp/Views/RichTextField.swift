import SwiftUI
import Dependencies

struct RichTextField: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @Environment(\.colorScheme) private var colorScheme
    @FocusState.Binding var isFocused: Bool
    @State private var isTextFieldVisible = false
    @State private var inputMessage: String

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

            if !richTextFieldState.workingApps.isEmpty {
                WorkingAppView(
                    workingApps: richTextFieldState.workingApps,
                    textAreaContents: richTextFieldState.textAreaContents,
                    onUpdateAXApp: richTextFieldDelegate.onUpdateWorkingApp
                )
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
                    .onChange(of: inputMessage) { _, newValue in
                        richTextFieldDelegate.onUpdateInputMessage(newValue)
                    }
                    .onKeyPress(.return) {
                        handleEnterKeyPress()
                    }
            }
            controlButtons
        }
        .textFieldBackground()
        #if os(macOS)
        .padding(.horizontal)
        .padding(.bottom)
        #endif
        .onChange(of: isFocused) { _, newValue in
            if !newValue {
                checkAndUpdateTextFieldVisibility()
            }
        }
        .onChange(of: richTextFieldState.inputMessage) { _, newValue in
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
                .padding(.vertical)
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
               AXAppSelectionMenu(onUpdateAXApp: richTextFieldDelegate.onUpdateWorkingApp)
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
                    handleSendAction()
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

    private func handleSendAction() {
        guard richTextFieldState.isMessageValid && !richTextFieldState.isRunning  else {
            return
        }
        richTextFieldDelegate.onSend()
    }

    private func handleEnterKeyPress() -> KeyPress.Result {
        if richTextFieldState.isMessageValid && !richTextFieldState.isRunning {
            DispatchQueue.main.async {
                handleSendAction()
            }
            return .handled
        }
        return .ignored
    }
}

struct TextFieldBackgroundView<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.all, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .light ? AppTheme.Colors.background : AppTheme.Colors.secondaryBackground)
                    #if os(iOS)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -2)
                    #endif
                    #if os(macOS)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.Colors.separator, lineWidth: 1)
                    )
                    #endif
            )
    }
}

extension View {
    func textFieldBackground() -> some View {
        TextFieldBackgroundView {
            self
        }
    }
}
