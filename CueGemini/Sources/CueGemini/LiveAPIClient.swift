import Foundation
import AVFoundation
import Combine
import SwiftUI
import CueCommon
import OSLog

public protocol LiveAPIClientProtocol: AnyObject {
    var voiceChatState: VoiceChatState { get }
    var voiceChatStatePublisher: AnyPublisher<VoiceChatState, Never> { get }
    var eventsPublisher: AnyPublisher<ServerMessage, Never> { get }
    func send<T: Encodable>(_ message: T) async throws
}

public protocol LiveAPIConnectionProtocol: Sendable {
    var events: AsyncThrowingStream<ServerMessage, Error> { get }
    var state: AsyncStream<WebsocketConnectionState> { get }
    func send<T: Encodable>(_ message: T) async throws
    func muteAudio()
    func unmuteAudio()
    func close()
}

public final class LiveAPIClient: @preconcurrency LiveAPIClientProtocol, @unchecked Sendable {
    let logger = Logger(subsystem: "LiveAPIClient", category: "LiveAPI")

    @MainActor
    public var voiceChatStatePublisher: AnyPublisher<VoiceChatState, Never> {
        voiceChatStateSubject.eraseToAnyPublisher()
    }
    @MainActor
    private let voiceChatStateSubject = CurrentValueSubject<VoiceChatState, Never>(.idle)
    private var state: VoiceChatState = .idle {
        didSet {
            logger.debug("Voice state change to \(self.state.description)")
            Task { @MainActor in
                voiceChatStateSubject.send(state)
            }
        }
    }

    @MainActor
    public var voiceChatState: VoiceChatState {
        voiceChatStateSubject.value
    }

    private let liveAPIEventSubject = PassthroughSubject<ServerMessage, Never>()
    
    @MainActor
    public var eventsPublisher: AnyPublisher<ServerMessage, Never> {
        liveAPIEventSubject.eraseToAnyPublisher()
    }

    private let audioManager = AudioManager()
    private var isListening: Bool = false
    private var connection: LiveAPIConnectionProtocol?
    private var connectionState: WebsocketConnectionState = .disconnected {
        didSet {
            logger.debug("connectionState change to : \(String(describing: self.connectionState))")
        }
    }
    private var eventSubscriptionTask: Task<Void, Error>?
    private var stateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        audioManager.delegate = self
    }

    @MainActor
    public func connect(apiKey: String, setupDetails: BidiGenerateContentSetup.SetupDetails) async throws {
        try await startSession(apiKey: apiKey, setupDetails: setupDetails)
    }

    @MainActor
    public func startSession(apiKey: String, setupDetails: BidiGenerateContentSetup.SetupDetails) async throws {
        guard state.canConnect else {
            logger.warning("Cannot start session in current state: \(self.state.description)")
            return
        }
        state = .connecting

        let liveAPI = LiveAPI()
        self.connection = try liveAPI.createConnection(apiKey: apiKey)
        let setup = BidiGenerateContentSetup(setup: setupDetails)
        try await self.connection?.send(setup)
        self.logger.debug("Sent initial setup message with model")

        setupConnectionSbuscription()
        try await setEventsSubscription()
        logger.info("Session started")
    }

    @MainActor
    public func endSession() {
        logger.debug("End session")
        audioManager.stopAudioEngine()
        self.connection?.close()
        self.connection = nil
        state = .idle
    }

    @MainActor public func pauseChat() {
        guard case .active = state else {
            logger.warning("Cannot pause chat in current state: \(self.state.description)")
            return
        }

        audioManager.pauseRecording()
        connection?.muteAudio()
        state = .paused
    }

    @MainActor public func resumeChat() {
        guard case .paused = state else {
            logger.warning("Cannot resume chat in current state: \(self.state.description)")
            return
        }

        audioManager.resumeRecording()
        connection?.unmuteAudio()
        state = .active
    }

    @MainActor public func endChat() async {
        logger.debug("End chat")
        switch state {
        case .active, .paused:
            endSession()
            state = .idle
        case .connecting:
            state = .idle
        case .error:
            endSession()
        case .idle:
            break
        }
    }

    @MainActor
    public func disconnect() {
        self.logger.debug("disconnect")
        self.audioManager.stopAudioEngine()
    }

    public func send<T>(_ message: T) async throws where T : Encodable {
        try await self.connection?.send(message)
    }

    private func setupConnectionSbuscription() {
        guard let connection = connection else { return }
        stateTask?.cancel()
        stateTask = Task {
            for await state in connection.state {
                await MainActor.run {
                    switch state {
                    case .connected:
                        self.connectionState = .connected
                        self.state = .active
                        self.handleConnection()
                    case .disconnected:
                        self.connectionState = .disconnected
                        self.state = .idle
                    case .connecting:
                        self.connectionState = .connecting
                        self.state = .connecting
                    case .error(let message):
                        logger.error("RealtimeClient error: \(message)")
                    }
                }
            }
        }
    }

    @MainActor
    private func handleConnection() {
        Task {
            do {
                try await audioManager.setupAudioEngine()
            } catch {
                let errorMessage = "Failed to setup audio: \(error)"
                logger.error("Handle connection error: \(errorMessage)")
                state = .error(errorMessage)
            }
        }
    }

    @MainActor
    private func handleDisconnection() {
        audioManager.stopAudioEngine()
    }

    private func setEventsSubscription() async throws {
        guard let connection = connection else { return }
        eventSubscriptionTask?.cancel()
        eventSubscriptionTask = Task {
            for try await event in connection.events {
                await self.handleMessage(event)
            }
        }
    }

    private func handleMessage(_ message: ServerMessage) async {
        liveAPIEventSubject.send(message)

        switch message {
        case .serverContent(let content):
            isListening = !(content.turnComplete == true)
            switch content.modelTurn.parts.first {
            case .data(mimetype: let mimetype, let data):
                logger.debug("Received data with mimetype: \(mimetype)")
                if mimetype.starts(with: "audio/pcm") {
                    audioManager.playAudioData(data, id: UUID().uuidString)
                }
            default:
                break
            }
        case .setupComplete:
            logger.debug("Setup completed successfully")
        default:
            break
        }
    }
}

extension LiveAPIClient: AudioManagerDelegate {
    public func audioManager(_ manager: AudioManager, didChangeState state: AudioManagerState) {
        self.logger.debug("audioManager didChangeState: \(state.description)")
    }

    public func audioManager(_ manager: AudioManager, didReceiveProcessedAudio data: Data) {
        Task { [weak self] in
            guard let self = self else { return }
            let base64Data = data.base64EncodedString()

            let chunk = BidiGenerateContentRealtimeInput.RealtimeInput.MediaChunk(
                mimeType: "audio/pcm",
                data: base64Data
            )
            let input = BidiGenerateContentRealtimeInput(realtimeInput: .init(mediaChunks: [chunk]))

            do {
                try await self.connection?.send(input)
            } catch {
                self.logger.error("Failed to send audio data: \(error.localizedDescription)")
            }
        }
    }

    func audioManager(_ manager: AudioManager, didUpdatePlaybackState isPlaying: Bool) {
        Task { @MainActor in
            self.logger.debug("isPlaying updated to \(isPlaying)")
        }
    }
}
