import AVFoundation
import SwiftUI

private let testToneFrequency: Double = 440 // A4 note
private let testToneDuration: TimeInterval = 1.0

public enum AudioFormat: Sendable {
    case pcm16bit24kHz
    case g711ALaw
    case g711ULaw
}

public func convertToFloat(_ data: Data) -> [Float] {
    return data.withUnsafeBytes { buffer in
        let int16Buffer = buffer.bindMemory(to: Int16.self)
        return int16Buffer.map { Float(Int16(littleEndian: $0)) / Float(Int16.max) }
    }
}

// G.711 decoding functions
public func DecodeALaw(_ sample: UInt8) -> Int16 {
    let sign = (sample & 0x80) >> 7
    var magnitude = Int16((sample & 0x7F) << 4)
    if (magnitude & 0x7C0) != 0x7C0 {
        magnitude |= 0x0F
    }
    let value = sign == 1 ? -magnitude : magnitude
    return value
}

public func DecodeULaw(_ sample: UInt8) -> Int16 {
    let sign = (sample & 0x80) >> 7
    var magnitude = Int16(~sample & 0x7F) << 3
    magnitude -= 0x84
    magnitude <<= 3
    let value = sign == 1 ? -magnitude : magnitude
    return value
}

extension AudioStreamPlayer {
    func decodeG711(data: Data, decoder: (UInt8) -> Int16) -> Data {
        var pcmData = Data(capacity: data.count * 2)
        for byte in data {
            let decodedSample = decoder(byte)
            pcmData.append(contentsOf: withUnsafeBytes(of: decodedSample.littleEndian) { Array($0) })
        }
        return pcmData
    }

    /// Plays a test tone for debugging purposes.
    func playTestTone() {
        print("Playing test tone")
        let sampleRate = 24000.0
        let frameCount = AVAudioFrameCount(sampleRate * testToneDuration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("Failed to create buffer for test tone")
            return
        }

        let theta = 2.0 * .pi * testToneFrequency / sampleRate

        for frame in 0..<Int(frameCount) {
            let value = sin(theta * Double(frame))
            buffer.floatChannelData?[0][frame] = Float(value)
        }

        buffer.frameLength = frameCount

        playerNode.scheduleBuffer(buffer) {
            print("Test tone playback completed")
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }

        if !isPlaying {
            playerNode.play()
            isPlaying = true
        }
    }

    func playLastAudioChunk() {
        guard let (data, format) = self.lastAudioChunk else {
            print("No audio chunk available to play")
            return
        }

        var pcmData: [Float]
        let sampleRate: Double = 24000.0 // Ensure this matches your audio data's sample rate

        switch format {
        case .pcm16bit24kHz:
            pcmData = convertToFloat(data)
        case .g711ALaw:
            let decodedData = decodeG711(data: data, decoder: DecodeALaw)
            pcmData = convertToFloat(decodedData)
        case .g711ULaw:
            let decodedData = decodeG711(data: data, decoder: DecodeULaw)
            pcmData = convertToFloat(decodedData)
        }

        // Clamp the pcmData to ensure values are within [-1.0, 1.0]
        pcmData = pcmData.map { max(min($0, 1.0), -1.0) }

        // Create AVAudioPCMBuffer from decoded PCM data
        let frameCount = pcmData.count // Each Float represents one frame for mono audio
        print("playLastAudioChunk pcmData.count: \(pcmData.count), frameCount: \(frameCount)")

        guard let avAudioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            print("Failed to create AVAudioFormat")
            return
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: avAudioFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
            print("Failed to create buffer for audio chunk")
            return
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<pcmData.count {
                channelData[i] = pcmData[i]
            }
        } else {
            print("Failed to access buffer's floatChannelData")
            return
        }

        print("Created AVAudioPCMBuffer with \(buffer.frameLength) frames")

        playerNode.scheduleBuffer(buffer) {
            print("Audio chunk playback completed")
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }

        if !isPlaying {
            playerNode.play()
            isPlaying = true
        }
    }
}
