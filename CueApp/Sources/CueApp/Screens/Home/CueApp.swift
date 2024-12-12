// #if os(iOS)
// import SwiftUI
// import OpenAI
// import AVFoundation
// import Combine
// import os.log
//
// public struct CueAppView: View {
//    public init() {}
//    @EnvironmentObject private var authService: AuthService
//    // @EnvironmentObject private var conversationManager: ConversationManager
//    @State private var inputMessage: String = ""
//    @State private var newAudio: Data?
//    @State private var authToken: String = ""
//    @State private var showingTokenManagement = false
//    @FocusState private var isFocused: Bool
//
//    @StateObject private var audioPlayer = AudioStreamPlayer()
//    @State private var lastProcessedEntryId: String?
//    @State private var audioProcessingTask: Task<Void, Never>?
//    @State private var processedEntryIds: Set<String> = []
//
//    @State private var isRecording = false
//    @StateObject private var audioRecorder = AudioRecorder()
//
//    private let logger = Logger(subsystem: "CueAppView", category: "CueAppView")
//
//    private var messages: [Item.Message] {
//        self.conversationManager.conversation?.entries.compactMap {
//            if case let .message(message) = $0 {
//                return message
//            }
//            return nil
//        } ?? []
//    }
//
//    public var body: some View {
//        VStack(spacing: 0) {
//            HStack {
//                Text("Chat")
//                    .font(.title)
//                    .padding()
//                Spacer()
//                optionsMenu
//                    .padding()
//            }
//
//            if authToken.isEmpty {
//                Text("Please set your API token to start chatting")
//                    .foregroundColor(.secondary)
//            } else {
//                ScrollView {
//                    VStack(spacing: 12) {
//                        ForEach(messages, id: \.id) { message in
//                            MessageRowView(message: message, audioPlayer: audioPlayer)
//                        }
//                    }
//                    .padding()
//                }
//
//                MessageInputViewAudio(
//                    inputMessage: $inputMessage,
//                    isFocused: _isFocused,
//                    isEnabled: true,
//                    isRecording: isRecording,
//                    onSend: sendMessage,
//                    onAudioButtonPressed: handleRecordingButton
//                )
//            }
//        }
//        .frame(maxWidth: 600)
//        .frame(maxWidth: .infinity, alignment: .center)
//        .sheet(isPresented: $showingTokenManagement) {
//            TokenManagementView(authToken: $authToken)
//        }
//        .onChange(of: authToken) { _, newValue in
//            if !newValue.isEmpty {
//                // self.conversationManager.initialize(authToken: newValue)
//            }
//        }
//        // .onChange(of: self.conversationManager.conversation?.entries) { _, _ in
//        //     DispatchQueue.main.async {
//        //         processNewAudioEntries()
//        //     }
//        // }
//        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
//            if !isAuthenticated {
//                cleanup()
//            }
//        }
//        .onAppear {
//            authToken = UserDefaults.standard.string(forKey: "ACCESS_TOKEN_KEY") ?? ""
//            if authToken.isEmpty {
//                let apiKey = try! Configuration.value(for: "OPENAI_API_KEY") as String
//                authToken = apiKey
//            }
//        }
//    }
//
//    private var optionsMenu: some View {
//        Menu {
//            Button("Manage Token") {
//                showingTokenManagement = true
//            }
//            Button("Play test tone") {
//                audioPlayer.playTestTone()
//            }
//            Button("Play latest audio chunk") {
//                audioPlayer.playLastAudioChunk()
//            }
//        } label: {
//            Label("Options", systemImage: "ellipsis.circle")
//        }
//    }
// }
//
// extension CueAppView {
//    private func handleRecordingButton() {
//        if isRecording {
//            audioRecorder.stopRecording()
//            newAudio = audioRecorder.audioData
//            sendAudio()
//        } else {
//            logger.debug("start recording")
//            audioRecorder.startRecording()
//        }
//        isRecording.toggle()
//    }
//
//    private func sendMessage() {
//        // guard inputMessage != "", let conversation = self.conversationManager.conversation else { return }
//
//        // Task {
//        //     try await conversation.send(from: .user, text: inputMessage)
//        //     inputMessage = ""
//        // }
//    }
//
//    private func sendAudio() {
//        // guard let audio = newAudio, let conversation = self.conversationManager.conversation else { return }
//        // Task {
//        //     try await conversation.send(audioDelta: audio, commit: true)
//        // }
//    }
//
//    private func processNewAudioEntries() {
//        // guard let entries = self.conversationManager.conversation?.entries else { return }
//        // let newEntries = entries.drop(while: { $0.id != lastProcessedEntryId })
//        let newEntries = []
//        logger.info("processNewAudioEntries entries size: \(entries.count) newEntries size: \(newEntries.count), newEntries:\(newEntries)")
//
//        let audioChunks = newEntries.flatMap { item -> [(Data, AudioFormat)] in
//            guard case let .message(message) = item else { return [] }
//            return message.content.compactMap { content -> (Data, AudioFormat)? in
//                switch content {
//                case let .audio(audio), let .input_audio(audio):
//                    // Determine the correct format based on audio data metadata
//                    let format: AudioFormat = .pcm16bit24kHz
//                    return (audio.audio, format)
//                default:
//                    return nil
//                }
//            }
//        }
//
//        if !audioChunks.isEmpty {
//            DispatchQueue.main.async {
//                logger.info("self.audioPlayer.appendAudioData audio chunks: \(audioChunks.count)")
//                self.audioPlayer.onLatestAudioDataChunk(audioChunks[0])
//            }
//        }
//
//        lastProcessedEntryId = entries.last?.id
//    }
// }
//
// extension CueAppView {
//    private func cleanup() {
//        // Stop any ongoing recording
//        if isRecording {
//            audioRecorder.stopRecording()
//            isRecording = false
//        }
//
//        // Cancel any ongoing audio processing
//        audioProcessingTask?.cancel()
//        audioProcessingTask = nil
//
//        // Clear conversation and state on a background thread
//        // self.conversationManager.cleanup()
//
//        // The rest of the state updates can remain on the main thread
//        inputMessage = ""
//        newAudio = nil
//        lastProcessedEntryId = nil
//        processedEntryIds.removeAll()
//        authToken = ""
//
//        // Clean up audio player
//        Task {
//            await audioPlayer.cleanup()
//        }
//
//        // Deactivate audio session
//
//        Task {
//            do {
//                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
//                logger.debug("Audio session deactivated successfully")
//            } catch {
//                logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
//            }
//        }
//    }
// }
// #endif
