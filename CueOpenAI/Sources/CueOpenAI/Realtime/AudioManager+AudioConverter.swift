@preconcurrency import AVFoundation

extension AudioManager {
    
    enum AudioConversionError: Error {
        case failedToCreateFormat
        case failedToCreateConverter
        case failedToCreateBuffer
        case conversionFailed(String)
        case failedToAccessChannelData
    }
    
    struct AudioConversionConfig {
        let sampleRate: Double
        let channels: UInt32
        let bitDepth: Int
        let isFloat: Bool
        
        static func pcm16(sampleRate: Double, channels: UInt32 = 1) -> AudioConversionConfig {
            AudioConversionConfig(sampleRate: sampleRate, channels: channels, bitDepth: 16, isFloat: false)
        }
        
        static func float32(sampleRate: Double, channels: UInt32 = 1) -> AudioConversionConfig {
            AudioConversionConfig(sampleRate: sampleRate, channels: channels, bitDepth: 32, isFloat: true)
        }
    }
    
    private func createAudioFormat(config: AudioConversionConfig) -> AVAudioFormat? {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: config.sampleRate,
            AVNumberOfChannelsKey: config.channels,
            AVLinearPCMBitDepthKey: config.bitDepth,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: config.isFloat
        ]
        return AVAudioFormat(settings: settings)
    }
    
    func convertBuffer(_ sourceBuffer: AVAudioPCMBuffer,
                      toConfig destinationConfig: AudioConversionConfig) throws -> AVAudioPCMBuffer {
        guard let destinationFormat = createAudioFormat(config: destinationConfig) else {
            throw AudioConversionError.failedToCreateFormat
        }
        
        guard let converter = AVAudioConverter(from: sourceBuffer.format, to: destinationFormat) else {
            throw AudioConversionError.failedToCreateConverter
        }
        
        let ratio = destinationFormat.sampleRate / sourceBuffer.format.sampleRate
        let destinationFrameCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio)
        
        guard let destinationBuffer = AVAudioPCMBuffer(pcmFormat: destinationFormat,
                                                      frameCapacity: destinationFrameCapacity) else {
            throw AudioConversionError.failedToCreateBuffer
        }
        
        destinationBuffer.frameLength = destinationFrameCapacity
        
        var error: NSError?
        let status = converter.convert(to: destinationBuffer, error: &error) { _, outStatus in
            outStatus.pointee = AVAudioConverterInputStatus.haveData
            return sourceBuffer
        }
        
        if status == .error {
            throw AudioConversionError.conversionFailed(error?.localizedDescription ?? "Unknown error")
        }
        
        return destinationBuffer
    }
    
    func convertPCMDataToBuffer(_ data: Data, config: AudioConversionConfig) throws -> AVAudioPCMBuffer {
        let frameCount = data.count / (config.bitDepth / 8)
        
        guard let sourceFormat = createAudioFormat(config: config) else {
            throw AudioConversionError.failedToCreateFormat
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: sourceFormat,
                                          frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw AudioConversionError.failedToCreateBuffer
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        if config.bitDepth == 16 {
            data.withUnsafeBytes { ptr in
                guard let samples = ptr.bindMemory(to: Int16.self).baseAddress else {
                    return
                }
                for i in 0..<frameCount {
                    buffer.int16ChannelData?[0][i] = samples[i]
                }
            }
        }
        
        return buffer
    }
    
    func convertBufferToInt16Data(_ buffer: AVAudioPCMBuffer) throws -> Data {
        guard let int16ChannelData = buffer.int16ChannelData else {
            throw AudioConversionError.failedToAccessChannelData
        }
        
        let frameCount = Int(buffer.frameLength)
        return Data(bytes: int16ChannelData[0],
                   count: frameCount * MemoryLayout<Int16>.size)
    }
}
