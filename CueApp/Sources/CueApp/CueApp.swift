import SwiftUI
import OpenAI
import AVFoundation
import Combine
import os.log

public struct CueAppView: View {
    public init() {}
    @State private var newMessage: String = ""
    @State private var newAudio: Data?
    @State private var authToken: String = ""
    @State private var showingTokenManagement = false
    @State private var conversation: Conversation?

    @StateObject private var audioPlayer = AudioStreamPlayer()
    @State private var lastProcessedEntryId: String?
    @State private var audioProcessingTask: Task<Void, Never>?
    @State private var processedEntryIds: Set<String> = []

    @State private var isRecording = false
    @StateObject private var audioRecorder = AudioRecorder()

    private let logger = Logger(subsystem: "CueAppView", category: "CueAppView")

    private var messages: [Item.Message] {
        conversation?.entries.compactMap {
            if case let .message(message) = $0 {
                return message
            }
            return nil
        } ?? []
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if authToken.isEmpty {
                    Text("Please set your API token to start chatting")
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(messages, id: \.id) { message in
                                MessageRowView(message: message, audioPlayer: audioPlayer)
                            }
                        }
                        .padding()
                    }

                    messageInputSection
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: optionsMenu)
            .sheet(isPresented: $showingTokenManagement) {
                TokenManagementView(authToken: $authToken)
            }
        }
        .onChange(of: authToken) { _, newValue in
            if !newValue.isEmpty {
                conversation = Conversation(authToken: newValue)
            }
        }
        .onChange(of: conversation?.entries) { _, _ in
            DispatchQueue.main.async {
                processNewAudioEntries()
            }
        }
        .onAppear {
            authToken = UserDefaults.standard.string(forKey: "API_KEY") ?? ""
            if authToken.isEmpty {
                let apiKey = try! Configuration.value(for: "OPENAI_API_KEY") as String
                authToken = apiKey
            }
        }
    }

    private var messageInputSection: some View {
        HStack(spacing: 12) {
            HStack {
                TextField("Chat", text: $newMessage, onCommit: { sendMessage() })
                    .frame(height: 40)
                    .submitLabel(.send)

                if !newMessage.isEmpty {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.white, .blue)
                    }
                }

                Button(action: handleRecordingButton) {
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

    private var optionsMenu: some View {
        Menu {
            Button("Manage Token") {
                showingTokenManagement = true
            }
            Button("Play test tone") {
                audioPlayer.playTestTone()
            }
            Button("Play latest audio chunk") {
                audioPlayer.playLastAudioChunk()
            }
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
        }
    }
}

struct MessageRowView: View {
    let message: Item.Message
    @ObservedObject var audioPlayer: AudioStreamPlayer

    var body: some View {
        VStack(alignment: .leading) {
            Text(message.role.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(message.content, id: \.id) { content in
                switch content {
                case .text(let text), .input_text(let text):
                    Text(text)
                case .audio(let audio), .input_audio(let audio):
                    if let transcript = audio.transcript {
                        Text(transcript)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

extension CueAppView {
    private func handleRecordingButton() {
        if isRecording {
            audioRecorder.stopRecording()
            newAudio = audioRecorder.audioData
            sendAudio()
        } else {
            logger.debug("start recording")
            audioRecorder.startRecording()
        }
        isRecording.toggle()
    }

    private func sendMessage() {
        guard newMessage != "", let conversation = conversation else { return }

        Task {
            try await conversation.send(from: .user, text: newMessage)
            newMessage = ""
        }
    }

    private func sendAudio() {
        guard let audio = newAudio, let conversation = conversation else { return }
        Task {
            try await conversation.send(audioDelta: audio, commit: true)
        }
    }

    private func processNewAudioEntries() {
        guard let entries = conversation?.entries else { return }
        let newEntries = entries.drop(while: { $0.id != lastProcessedEntryId })
        logger.info("processNewAudioEntries entries size: \(entries.count) newEntries size: \(newEntries.count), newEntries:\(newEntries)")

        let audioChunks = newEntries.flatMap { item -> [(Data, AudioFormat)] in
            guard case let .message(message) = item else { return [] }
            return message.content.compactMap { content -> (Data, AudioFormat)? in
                switch content {
                case let .audio(audio), let .input_audio(audio):
                    // Determine the correct format based on audio data metadata
                    let format: AudioFormat = .pcm16bit24kHz
                    return (audio.audio, format)
                default:
                    return nil
                }
            }
        }

        if !audioChunks.isEmpty {
            DispatchQueue.main.async {
                logger.info("self.audioPlayer.appendAudioData audio chunks: \(audioChunks.count)")
                self.audioPlayer.onLatestAudioDataChunk(audioChunks[0])
            }
        }

        lastProcessedEntryId = entries.last?.id
    }
}
