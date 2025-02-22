import Foundation
import Combine
import CueCommon
import os.log

public protocol RealtimeClientProtocol: AnyObject {
    var voiceChatState: VoiceChatState { get }
    var voiceChatStatePublisher: AnyPublisher<VoiceChatState, Never> { get }
    var eventsPublisher: AnyPublisher<ServerEvent, Never> { get }
    func send(event: ClientEvent) async throws
}

public protocol RealtimeConnectionProtocol: Sendable {
    var events: AsyncThrowingStream<ServerEvent, Error> { get }
    var state: AsyncStream<RealtimeConnectionState> { get }
    func send(event: ClientEvent) async throws
    func muteAudio()
    func unmuteAudio()
    func close()
}

public final class RealtimeClient: @preconcurrency RealtimeClientProtocol, @unchecked Sendable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RealtimeClient",
                              category: "RealtimeClient")
    
    // MARK: - State Management
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
    
    private let realtimeMessageSubject = PassthroughSubject<ServerEvent, Never>()
    
    @MainActor
    public var eventsPublisher: AnyPublisher<ServerEvent, Never> {
        realtimeMessageSubject.eraseToAnyPublisher()
    }
    
    private let realtimeAPI: RealtimeAPIProtocol
    private let transport: RealtimeTransport
    private let messageProcessor: RealtimeMessageProcessor
    private var audioManager: AudioManager?
    private var connection: RealtimeConnectionProtocol?
    
    private var connectionState: RealtimeConnectionState = .disconnected {
        didSet {
            logger.debug("connectionState change to : \(String(describing: self.connectionState))")
        }
    }
    private var eventSubscriptionTask: Task<Void, Error>?
    private var stateTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    
    public init(transport: RealtimeTransport) {
        self.transport = transport
        self.messageProcessor = RealtimeMessageProcessor()
        self.realtimeAPI = RealtimeAPI(transport: transport)
    }
    
    deinit {
        eventSubscriptionTask?.cancel()
        eventSubscriptionTask = nil
        stateTask?.cancel()
        stateTask = nil
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
    
    private func setEventsSubscription() async throws {
        guard let connection = connection else { return }
        eventSubscriptionTask?.cancel()
        eventSubscriptionTask = Task {
            for try await event in connection.events {
                await self.handleEvent(event)
            }
        }
    }
    
    private func handleEvent(_ event: ServerEvent) async {
        realtimeMessageSubject.send(event)
        
        switch event {
        case .error(let errorEvent):
            handleErrorEvent(errorEvent)
        case .responseAudioDelta(let audioDeltaEvent):
            handleAudioDelta(audioDeltaEvent.delta, id: audioDeltaEvent.eventId)
        case .responseAudioTranscriptDelta:
            break
        default:
            break
        }
    }
    
    private func handleErrorEvent(_ errorEvent: ServerError) {
        state = .error(errorEvent.error.message)
        logger.debug("handleMessage error: \(String(describing: errorEvent))")
    }
    
    private func handleAudioDelta(_ delta: String, id: String) {
        guard let decodedAudioData = Data(base64Encoded: delta) else {
            logger.error("Failed to decode base64 audio delta")
            return
        }
        audioManager?.playAudioData(decodedAudioData, id: id)
    }
    
    public func send(event: ClientEvent) async throws {
        try await self.connection?.send(event: event)
    }
    
    // MARK: - Session Management
    
    @MainActor
    public func startSession(apiKey: String, model: String, sessionCreate: RealtimeSession? = nil) async throws {
        guard !apiKey.isEmpty && !model.isEmpty else {
            throw RealtimeClientError.invalidConfiguration("API key and model cannot be empty")
        }
        
        guard case .idle = state else {
            logger.warning("Cannot start session in current state: \(self.state.description)")
            return
        }
        
        state = .connecting
        let config = RealtimeConfig(apiKey: apiKey, model: model)
        self.connection = try await realtimeAPI.createConnection(config: config, sessionCreate: sessionCreate)
        setupConnectionSbuscription()
        try await setEventsSubscription()
        logger.info("Session started")
    }
    
    @MainActor public func endSession() {
        logger.debug("End session")
        audioManager?.stopAudioEngine()
        self.connection?.close()
        self.connection = nil
        state = .idle
    }
    
    @MainActor public func pauseChat() {
        guard case .active = state else {
            logger.warning("Cannot pause chat in current state: \(self.state.description)")
            return
        }
        
        audioManager?.pauseRecording()
        connection?.muteAudio()
        state = .paused
    }
    
    @MainActor public func resumeChat() {
        guard case .paused = state else {
            logger.warning("Cannot resume chat in current state: \(self.state.description)")
            return
        }
        
        audioManager?.resumeRecording()
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
    
    private func setupAudioManager() async throws {
        guard .webSocket == transport else {
            return
        }
        do {
            let audioManager = AudioManager()
            audioManager.delegate = self
            self.audioManager = audioManager
            try await audioManager.setupAudioEngine()
        } catch {
            state = .error("Failed to setup audio: \(error)")
            throw error
        }
    }
    
    public func createResponse() async throws {
        let event = ClientEvent.responseCreate(
            ClientEvent.ResponseCreateEvent(response: nil)
        )
        try await send(event: event)
    }
    
    private func handleError(_ error: RealtimeClientError) {
        let errorMessage = error.localizedDescription
        logger.error("Handle error: \(error)")
        state = .error(errorMessage)
    }
    
    private func sendInputAudioBufferAppendEvent(audio: Data) {
        guard case .connected = connectionState else {
            logger.error("Cannot send audio: WebSocket not connected. \(String(describing: self.connectionState))")
            Task { @MainActor in
                handleDisconnection()
            }
            return
        }
        let event = ClientEvent.InputAudioBufferAppendEvent(
            eventId: nil,
            audio: audio.base64EncodedString()
        )
        Task {
            do {
                try await send(event: .inputAudioBufferAppend(event))
            } catch {
                logger.error("Failed to send input audio buffer append event: \(error)")
            }
        }
    }
    
    @MainActor
    private func handleConnection() {
        Task {
            do {
                try await setupAudioManager()
            } catch {
                let errorMessage = "Failed to setup audio: \(error)"
                logger.error("Handle connection error: \(errorMessage)")
                state = .error(errorMessage)
            }
        }
    }
    
    @MainActor
    private func handleDisconnection() {
        audioManager?.stopAudioEngine()
    }
}

// MARK: - AudioManagerDelegate
extension RealtimeClient: AudioManagerDelegate {
    func audioManager(_ manager: AudioManager, didReceiveProcessedAudio data: Data) {
        sendInputAudioBufferAppendEvent(audio: data)
    }
    
    func audioManager(_ manager: AudioManager, didChangeState audioState: AudioManagerState) {
        switch audioState{
        case .started:
            state = .active
        case .paused:
            guard case .active = state else {
                logger.error("Audio manager paused while service state is not active")
                return
            }
            state = .paused
        case .resumed:
            guard case .paused = state else {
                logger.error("Audio manager resumed while service state is not paused")
                return
            }
            state = .active
        case .stopped:
            state = .idle
        case .error(let error):
            handleError(.generic("Audio manager error: \(error.localizedDescription)"))
        default:
            break
        }
    }
}
