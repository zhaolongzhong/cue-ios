import SwiftUI
import Dependencies

struct RichTextField: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @Environment(\.colorScheme) private var colorScheme
    let isEnabled: Bool
    let showVoiceChat: Bool
    let showAXApp: Bool
    let onShowTools: () -> Void
    let onOpenVoiceChat: (() -> Void)?
    let onStartAXApp: ((AccessibleApplication) -> Void)?
    let onSend: () -> Void
    let toolCount: Int
    @Binding var inputMessage: String
    @FocusState.Binding var isFocused: Bool
    @State private var isTextFieldVisible = false

    init(
        isEnabled: Bool = true,
        showVoiceChat: Bool = false,
        showAXapp: Bool = false,
        onShowTools: @escaping () -> Void,
        onOpenVoiceChat: (() -> Void)? = nil,
        onStartAXApp: ((AccessibleApplication) -> Void)? = nil,
        onSend: @escaping () -> Void,
        toolCount: Int = 0,
        inputMessage: Binding<String>,
        isFocused: FocusState<Bool>.Binding
    ) {
        self.isEnabled = isEnabled
        self.showVoiceChat = showVoiceChat
        self.showAXApp = showAXapp
        self.onShowTools = onShowTools
        self.onOpenVoiceChat = onOpenVoiceChat
        self.onStartAXApp = onStartAXApp
        self.onSend = onSend
        self.toolCount = toolCount
        self._inputMessage = inputMessage
        self._isFocused = isFocused
    }

    var body: some View {
        VStack {
            if isTextFieldVisible {
                HStack {
                    TextField("Type a message...", text: $inputMessage, axis: .vertical)
                        .scrollContentBackground(.hidden)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.top, 12)
                        .lineLimit(1...5)
                        .focused($isFocused)
                        .background(.clear)
                        .onSubmit {
                            if isMessageValid {
                                onSend()
                            }
                        }
                        .submitLabel(.return)
                }
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
                AttachmentPickerMenu()
            }
            Text("Type a message ...")
                .foregroundColor(.secondary.opacity(0.6))
                .opacity(isTextFieldVisible ? 0 : 1)
            Spacer()
            if toolCount != 0 {
                ToolButton(count: toolCount, action: {
                    onShowTools()
                    checkAndUpdateTextFieldVisibility()
                })
            }
            if showAXApp {
                AXAppSelectionMenu(onStartAXApp: onStartAXApp)
            }
            if showVoiceChat {
                VoiceChatButton(action: {
                    onOpenVoiceChat?()
                    checkAndUpdateTextFieldVisibility()
                })
            }
            SendButton(isEnabled: isMessageValid, action: onSend)
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
        inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1
    }
}

struct AttachmentPickerMenu: View {
    var body: some View {
        HoverButton {
            Menu {
                Button {
                    // Handle attach photos
                } label: {
                    Label("Attach Photos", systemImage: "photo")
                }

                Button {
                    // Handle attach files
                } label: {
                    Label("Attach Files", systemImage: "folder")
                }
            } label: {
                Label("", systemImage: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .imageScale(.large)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

struct ToolButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        HoverButton {
            Button(action: action) {
                HStack(spacing: 2) {
                    Image(systemName: "hammer")
                        .font(.system(size: 12))
                    Text("\(count)")
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct VoiceChatButton: View {
    let action: () -> Void

    var body: some View {
        HoverButton {
            Button(action: action) {
                Image(systemName: "waveform")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
    }
}

struct AXAppSelectionMenu: View {
    @State private var selectedApp: AccessibleApplication = .textEdit
    let onStartAXApp: ((AccessibleApplication) -> Void)?

    var body: some View {
        HoverButton {
            Menu {
                ForEach(AccessibleApplication.allCases, id: \.self) { app in
                    Button {
                        selectedApp = app
                        onStartAXApp?(selectedApp)
                    } label: {
                        Text(app.name)
                            .frame(minWidth: 200, alignment: .leading)
                    }
                }
            } label: {
                Image(systemName: "link.badge.plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
