#if os(iOS)
import AVFoundation
import Combine
import os.log

private let logger = Logger(subsystem: "AudioStreamPlayer", category: "AudioStreamPlayer")

class QueueBuffer {
    private var queue: [Float] = []
    private let accessQueue = DispatchQueue(label: "QueueBufferInternalAccessQueue")

    func enqueue(_ data: [Float]) {
        accessQueue.sync {
            self.queue.append(contentsOf: data)
            print("QueueBuffer enqueue: Enqueued \(data.count) samples. Queue count: \(self.queue.count)")
        }
    }

    func dequeue(count: Int) -> [Float] {
        return accessQueue.sync {
            let availableCount = min(count, self.queue.count)
            let result = Array(self.queue.prefix(availableCount))
            if availableCount > 0 {
                self.queue.removeFirst(availableCount)
            }
            print("QueueBuffer dequeue: Dequeued \(availableCount) samples. Queue count: \(self.queue.count)")
            return result
        }
    }
    func clear() {
        accessQueue.sync {
            queue.removeAll()
        }
    }

    var count: Int {
        return accessQueue.sync { queue.count }
    }
}

class AudioStreamPlayer: ObservableObject, @unchecked Sendable {

    private let engine: AVAudioEngine
    let playerNode: AVAudioPlayerNode
    private let mixer: AVAudioMixerNode
    private let bufferSize: AVAudioFrameCount = 4096 // latency: 4096 / 24000 ≈ 0.170 seconds
    private var currentFormat: AudioFormat = .pcm16bit24kHz
    private var avAudioFormat: AVAudioFormat
    private var isScheduling = false
    var lastAudioChunk: (Data, AudioFormat)?

    private let queueBuffer: QueueBuffer
    // processingQueue:
    // Ensures that audio data is prepared and ready for scheduling without blocking the main thread.
    private let processingQueue = DispatchQueue(label: "audioProcessing", qos: .userInteractive)
    // monitoringQueue:
    // Oversees the queueBuffer to determine when enough audio data is available to schedule for playback.
    // It runs a continuous loop that periodically checks the buffer and triggers the scheduling of audio buffers when necessary.
    private let monitoringQueue = DispatchQueue(label: "audioMonitoring", qos: .background)

    @Published var isPlaying = false

    // Flag to control monitoring loop
    private var isRunning = true

    // Tracking the last processed data length
    private var lastProcessedLength: Int = 0

    init(initialFormat: AudioFormat = .pcm16bit24kHz) {
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixer = AVAudioMixerNode()

        // Initialize AVAudioFormat to Float32 based on the initial format
        avAudioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: initialFormat == .pcm16bit24kHz ? 24000 : 8000,
            channels: 1,
            interleaved: false
        )!

        queueBuffer = QueueBuffer()

        engine.attach(playerNode)
        engine.attach(mixer)

        setupAudioSession(sampleRate: avAudioFormat.sampleRate)
        setupAudioChain()
        startAudioProcessing()
    }

    private func setupAudioSession(sampleRate: Double) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])

            try session.setPreferredSampleRate(sampleRate)
            try session.setActive(true)
            let actualSampleRate = session.sampleRate
            print("setupAudioSession setPreferredSampleRate, sampleRate:\(sampleRate), actualSampleRate:\(actualSampleRate)")
        } catch {
            logger.error("Failed to set up audio session: \(error.localizedDescription)")
        }
    }

    private func setupAudioChain() {
        // Connect playerNode to mixer with avAudioFormat
        engine.connect(playerNode, to: mixer, format: avAudioFormat)
        // Connect mixer to mainMixerNode without specifying a format to allow automatic conversion
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)

        playerNode.volume = 1.0
        mixer.volume = 1.0

        do {
            try engine.start()
            logger.info("Audio engine started successfully at sample rate: \(self.engine.mainMixerNode.outputFormat(forBus: 0).sampleRate) Hz")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    /// Handles incoming audio data chunks.
    /// - Parameter audioChunk: Tuple containing audio data, optional transcript, and audio format.
    func onLatestAudioDataChunk(_ audioChunk: (Data, AudioFormat)) {
        // The audioChunk contains the very beginning of the audio data till latest audio data
        // It's called from main thread
        print("appendAudioData audioChunk: \(audioChunk)")
        processingQueue.async { [weak self] in
            print("entered processingQueue.async block")
            guard let self = self else {
                return
            }

            let (data, format) = audioChunk

            // Handle empty data chunks as a signal to flush remaining data
            if data.isEmpty {
                print("received empty audio chunk, triggering flush")
                self.flushBuffer()
                return
            }

            lastAudioChunk = audioChunk

            if data.count < self.lastProcessedLength {
                // it's next message, reset lastProcessedLength
                self.lastProcessedLength = 0
                return
            }

            if data.count <= self.lastProcessedLength {
                print("no new data to process, lastDataLength: \(self.lastProcessedLength), data.count: \(data.count)")
                return
            }

            // Extract new data
            let newDataRange = self.lastProcessedLength..<data.count
            let newData = data.subdata(in: newDataRange)
            self.lastProcessedLength = data.count

            if !newData.isEmpty {
                if format != self.currentFormat {
                    self.updateAudioFormat(format)
                }
                self.appendAudioDataInternal(newData)
            } else {
                print("skipping empty new data chunk")
            }
        }
    }

    /// Updates the audio format when a new format is detected.
    /// - Parameter format: New audio format to update to.
    private func updateAudioFormat(_ format: AudioFormat) {
        guard format != currentFormat else { return }
        currentFormat = format
        let newSampleRate: Double = format == .pcm16bit24kHz ? 24000 : 8000
        setupAudioSession(sampleRate: newSampleRate)
        avAudioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: newSampleRate, channels: 1, interleaved: false)!

        // Restart audio chain to apply new format
        engine.stop()
        setupAudioChain()

        logger.info("Audio format updated: \(self.avAudioFormat.sampleRate) Hz, \(self.avAudioFormat.channelCount) channels, \(self.avAudioFormat.commonFormat.rawValue)")
    }

    /// Appends audio data to the queue buffer after processing.
    /// - Parameter data: Raw audio data to process and enqueue.
    private func appendAudioDataInternal(_ data: Data) {
        print("appendAudioDataInternal started with \(data.count) bytes")
        var pcmData: [Float]

        switch currentFormat {
        case .pcm16bit24kHz:
            pcmData = convertToFloat(data)
        case .g711ALaw:
            let decodedData = decodeG711(data: data, decoder: DecodeALaw)
            pcmData = convertToFloat(decodedData)
        case .g711ULaw:
            let decodedData = decodeG711(data: data, decoder: DecodeULaw)
            pcmData = convertToFloat(decodedData)
        }

        // Clamp Float samples to [-1.0, 1.0] to prevent clipping
        pcmData = pcmData.map { max(min($0, 1.0), -1.0) }

        print("writing \(pcmData.count) float samples to queue buffer")
        queueBuffer.enqueue(pcmData)

        if !isScheduling {
            scheduleBuffer()
        } else {
            logger.debug("not calling scheduleBuffer, already scheduling")
        }
    }

    /// Starts the audio processing loop that monitors and schedules buffers.
    private func startAudioProcessing() {
        monitoringQueue.async { [weak self] in
            guard let self = self else { return }
            while self.isRunning {
                if self.queueBuffer.count >= Int(self.bufferSize) {
                    self.scheduleBuffer()
                }
                Thread.sleep(forTimeInterval: 0.01)  // Sleep for 10ms before checking again
            }
        }
    }

    private func scheduleBuffer(flush: Bool = false) {
        guard !isScheduling else {
            return
        }
        logger.debug("scheduleBuffer started, isScheduling: \(self.isScheduling)")

        isScheduling = true

        // Determine how many samples to read
        let samplesToRead = flush ? queueBuffer.count : Int(bufferSize)
        let audioData = queueBuffer.dequeue(count: samplesToRead)

        guard !audioData.isEmpty else {
            isScheduling = false
            return
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: avAudioFormat, frameCapacity: AVAudioFrameCount(audioData.count)) else {
            isScheduling = false
            return
        }
        buffer.frameLength = AVAudioFrameCount(audioData.count)

        let channelData = buffer.floatChannelData![0]
        // Ensure safe copying of data
        for i in 0..<audioData.count {
            channelData[i] = audioData[i]
        }
        logger.debug("created AVAudioPCMBuffer with \(buffer.frameLength) frames")

        // Capture the flush flag in the closure
        playerNode.scheduleBuffer(buffer) { [weak self, flush] in
            guard let self = self else {
                return
            }
            DispatchQueue.main.async {
                self.isScheduling = false
                if flush {
                    // If flushing, stop the player node after the last buffer is played
                    self.playerNode.stop()
                    self.isPlaying = false
                } else {
                    self.scheduleBuffer()
                }
            }
        }

        if !isPlaying {
            DispatchQueue.main.async {
                self.playerNode.play()
                self.isPlaying = true
            }
        }
    }

    func stop() {
        isPlaying = false
        flushBuffer()
    }

    /// Flushes all remaining audio data in the queue buffer for playback.
    private func flushBuffer() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            if self.queueBuffer.count > 0 {
                self.scheduleBuffer(flush: true)
            }
        }
    }

    private var cleanupComplete = false

    func cleanup() async {
        guard !cleanupComplete else { return }

        // 1. Stop monitoring first
        isRunning = false

        // 2. Stop playback and clear scheduling state
        playerNode.stop()
        isPlaying = false
        isScheduling = false

        // 3. Clear all buffers
        queueBuffer.clear()
        lastAudioChunk = nil
        lastProcessedLength = 0

        // 4. Let the run loop process the state changes
        try? await Task.sleep(for: .milliseconds(50))

        // 5. Stop and detach nodes
        engine.stop()
        engine.detach(playerNode)
        engine.detach(mixer)

        // 6. Reset format
        currentFormat = .pcm16bit24kHz

        cleanupComplete = true
    }

}
#endif
