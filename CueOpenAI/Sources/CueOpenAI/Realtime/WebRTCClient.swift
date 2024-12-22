@preconcurrency
import WebRTC
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import os.log

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCClient(_ client: WebRTCClient, didChangeDataChannelState state: RTCDataChannelState)
}

public final class WebRTCClient: NSObject, @unchecked Sendable {
    enum WebRTCError: Error {
        case failedToCreateDataChannel
        case failedToCreatePeerConnection
        case badServerResponse
    }
    
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory()
    }()
    
    weak var delegate: WebRTCClientDelegate?
    private let peerConnection: RTCPeerConnection
    #if os(iOS)
    private let rtcAudioSession =  RTCAudioSession.sharedInstance()
    #endif
    private let audioQueue = DispatchQueue(label: "audio")
    private let mediaConstrains = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                                   kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
    
    private var localDataChannel: RTCDataChannel?
    private var remoteDataChannel: RTCDataChannel?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrackCount: Int = 0
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "WebRTCClient",
                                  category: "WebRTCClient")
    
    // MARK: - Initialization
    public required init(iceServers: [String] = []) {
        // Reference: https://github.com/stasel/WebRTC-iOS/blob/main/WebRTC-Demo-App/Sources/Services/WebRTCClient.swift

        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement":kRTCMediaConstraintsValueTrue])
        
        guard let peerConnection = WebRTCClient.factory.peerConnection(with: config, constraints: constraints, delegate: nil) else {
            fatalError("Could not create new RTCPeerConnection")
        }
        
        self.peerConnection = peerConnection
        
        super.init()
        self.createMediaSenders()
        #if os(iOS)
        self.configureAudioSession()
        #endif
        peerConnection.delegate = self
    }
    
    public func close() {
        self.peerConnection.close()
    }
    
    func performSignaling(with request: URLRequest) async throws {
        var request = request
        do {
            let offer = try await self.peerConnection.offer(for: .init(mandatoryConstraints: nil, optionalConstraints: nil))
            try await self.peerConnection.setLocalDescription(offer)
    
            request.httpMethod = "POST"
            request.httpBody = offer.sdp.data(using: .utf8)
    
            let (data, res) = try await URLSession.shared.data(for: request)
            if let httpResponse = res as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    let serverMessage = String(data: data, encoding: .utf8) ?? "No message"
                    logger.error("WebRTC signaling failed: \(String(describing: httpResponse.statusCode)), \(serverMessage)")
                }
            }
    
            guard let httpResponse = res as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let sdp = String(data: data, encoding: .utf8) else {
                throw WebRTCError.badServerResponse
            }
            logger.debug("WebRTC setRemoteDescription with SDP: \(String(describing: sdp))")
            try await self.peerConnection.setRemoteDescription(
                RTCSessionDescription(type: .answer, sdp: sdp)
            )
        } catch {
            throw error
        }
    }
    
    private func createMediaSenders() {
        let streamId = "stream"
        self.localAudioTrack = self.createAudioTrack()
        if let audioTrack = self.localAudioTrack {
            self.peerConnection.add(audioTrack, streamIds: [streamId])
        }
        
        if let dataChannel = createDataChannel() {
            dataChannel.delegate = self
            self.localDataChannel = dataChannel
        }
    }
    
    private func createAudioTrack() -> RTCAudioTrack {
        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: [
                "googEchoCancellation": "true",
                "googAutoGainControl": "true",
                "googNoiseSuppression": "true",
                "googHighpassFilter": "true"
            ]
        )
        let audioSource = WebRTCClient.factory.audioSource(with: audioConstraints)
        let audioTrack = WebRTCClient.factory.audioTrack(with: audioSource, trackId: "audio0")
        return audioTrack
    }

    #if os(iOS)
    private func configureAudioSession() {
        self.rtcAudioSession.lockForConfiguration()
        do {
            try self.rtcAudioSession.setCategory(.playAndRecord,
                                                mode: .voiceChat,
                                                options: [.allowBluetooth,
                                                          .defaultToSpeaker,
                                                          .interruptSpokenAudioAndMixWithOthers,
                                                          .duckOthers])
            try self.rtcAudioSession.setActive(true)
        } catch {
            logger.error("Configure audio session failed: \(String(describing: error))")
        }
        self.rtcAudioSession.unlockForConfiguration()
    }
    #endif
    
    private func createDataChannel() -> RTCDataChannel? {
        let config = RTCDataChannelConfiguration()
        guard let dataChannel = self.peerConnection.dataChannel(forLabel: "oai-events", configuration: config) else {
            logger.error("Couldn't create data channel.")
            return nil
        }
        return dataChannel
    }
    
    func sendData(_ data: Data) {
        let buffer = RTCDataBuffer(data: data, isBinary: true)
        self.remoteDataChannel?.sendData(buffer)
    }
    
    // MARK: - Sending Client Events
    public func send(event: ClientEvent) async throws {
        do {
            let buffer = try RTCDataBuffer(data: encoder.encode(event), isBinary: false)
            localDataChannel?.sendData(buffer)
        } catch {
            throw error
        }
    }
    
    func muteAudio() {
        guard let localAudioTrack = localAudioTrack else { return }
        localAudioTrack.isEnabled = false
    }
    
    func unmuteAudio() {
        guard let localAudioTrack = localAudioTrack else { return }
        localAudioTrack.isEnabled = true
    }
    
    private func handleRemoteAudioTrackAdded(_ audioTrack: RTCAudioTrack) {
        remoteAudioTrackCount += 1
        logger.debug("Total remote audio tracks: \(self.remoteAudioTrackCount)")
    }

    private func handleRemoteAudioTrackRemoved(_ audioTrack: RTCAudioTrack) {
        remoteAudioTrackCount = max(remoteAudioTrackCount - 1, 0)
        logger.debug("Total remote audio tracks: \(self.remoteAudioTrackCount)")
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCClient: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        logger.debug("RTCPeerConnectionDelegate - Connection state changed to \(String(describing: stateChanged))")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        logger.debug("RTCPeerConnectionDelegate - Media stream added.")
        for audioTrack in stream.audioTracks {
            self.handleRemoteAudioTrackAdded(audioTrack)
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        logger.debug("RTCPeerConnectionDelegate - Media stream removed.")
        for audioTrack in stream.audioTracks {
            self.handleRemoteAudioTrackRemoved(audioTrack)
        }
    }

    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        logger.debug("RTCPeerConnectionDelegate - Negotiating connection.")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        self.delegate?.webRTCClient(self, didChangeConnectionState: newState)
        logger.debug("RTCPeerConnectionDelegate - ICE connection state changed to \(String(describing: newState))")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        logger.debug("RTCPeerConnectionDelegate - ICE gathering state changed to \(String(describing: newState))")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        logger.debug("RTCPeerConnectionDelegate - ICE candidate generated: \(String(describing: candidate.sdp))")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        logger.debug("RTCPeerConnectionDelegate - ICE candidates removed.")
    }

    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        logger.debug("RTCPeerConnectionDelegate - Data channel opened: \(dataChannel.label)")
        self.remoteDataChannel = dataChannel
    }
}

// MARK: - RTCDataChannelDelegate
extension WebRTCClient: RTCDataChannelDelegate {
    public func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        logger.debug("RTCDataChannelDelegate - DataChannel state changed to: \(dataChannel.readyState.rawValue)")
        self.delegate?.webRTCClient(self, didChangeDataChannelState: dataChannel.readyState)
        if dataChannel.readyState == .open {
            logger.debug("RTCDataChannelDelegate - DataChannel is open and ready to send/receive messages.")
            
        } else if dataChannel.readyState == .closed {
                logger.debug("RTCDataChannelDelegate - DataChannel is closed.")
        }
    }

    public func dataChannel(_: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        self.delegate?.webRTCClient(self, didReceiveData: buffer.data)
    }
}
