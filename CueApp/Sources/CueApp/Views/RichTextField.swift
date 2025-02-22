import SwiftUI
import Dependencies

struct RichTextField: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = RichTextFieldViewModel()
    
    let isEnabled: Bool
    let showVoiceChat: Bool
    let showAXApp: Bool
    let onShowTools: () -> Void
    let onOpenVoiceChat: (() -> Void)?
    let onStartAXApp: ((AccessibleApplication) -> Void)?
    let onAttachmentSelected: ((Attachment) -> Void)?
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
        onAttachmentSelected: ((Attachment) -> Void)? = nil,
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
        self.onAttachmentSelected = onAttachmentSelected
        self.onSend = onSend
        self.toolCount = toolCount
        self._inputMessage = inputMessage
        self._isFocused = isFocused
    }

    var body: some View {
        VStack(spacing: 0) {
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

            HStack {
                if featureFlags.enableMediaOptions {
                    Menu {
                        Button {
                            Task {
                                await viewModel.handleImage(from: .photoLibrary)
                                if let attachment = viewModel.attachments.last {
                                    onAttachmentSelected?(attachment)
                                }
                            }
                        } label: {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        
                        Button {
                            Task {
                                await viewModel.handleImage(from: .camera)
                                if let attachment = viewModel.attachments.last {
                                    onAttachmentSelected?(attachment)
                                }
                            }
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                        
                        Button {
                            Task {
                                await viewModel.handleAttachment(type: .document)
                                if let attachment = viewModel.attachments.last {
                                    onAttachmentSelected?(attachment)
                                }
                            }
                        } label: {
                            Label("Document", systemImage: "doc")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20))
                            .foregroundColor(Color.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
                Text("Type a message ...")
                    .foregroundColor(.secondary.opacity(0.6))
                    .opacity(isTextFieldVisible ? 0 : 1)
                Spacer()
                if toolCount != 0 {
                    Button {
                        onShowTools()
                        checkAndUpdateTextFieldVisibility()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "hammer")
                                .font(.system(size: 12))
                                .foregroundColor(Color.secondary)
                                .background(Color.clear)
                            Text("\(toolCount)").foregroundColor(Color.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                if showAXApp {
                    AXAppSelectionMenu(onStartAXApp: onStartAXApp)
                }
                if showVoiceChat {
                    Button {
                        onOpenVoiceChat?()
                        checkAndUpdateTextFieldVisibility()
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "waveform")
                                .font(.system(size: 20))
                                .foregroundColor(Color.secondary)
                                .background(Color.clear)
                        }
                    }
                    .buttonStyle(.plain)
                }
                SendButton(isEnabled: isMessageValid, action: onSend)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showTextField()
            }
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
        inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }
}
