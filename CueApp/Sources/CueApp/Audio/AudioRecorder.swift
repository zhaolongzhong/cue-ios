#if os(iOS)
import AVFoundation
import SwiftUI
import Combine
import os.log

class AudioRecorder: ObservableObject, @unchecked Sendable {
    private var audioRecorder: AVAudioRecorder?
    @Published var audioData: Data?
    private var recordingURL: URL?

    private let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false
    ]

    init() {
         // Configure and activate the audio session when initializing
         DispatchQueue.global(qos: .userInitiated).async {
             self.configureAudioSession()
         }

         // Add an observer to deactivate the audio session when the app is terminated or backgrounded
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(deactivateAudioSession),
             name: UIApplication.willTerminateNotification,
             object: nil
         )
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(deactivateAudioSession),
             name: UIApplication.didEnterBackgroundNotification,
             object: nil
         )
     }

    func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            AppLog.recorder.error("Failed to set up audio session: \(error)")
        }
    }

    func startRecording() {
        let recordingURL = getDocumentsDirectory().appendingPathComponent("recording.wav")

        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
        } catch {
            AppLog.recorder.error("Could not start recording: \(error)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        if let url = audioRecorder?.url {
            audioData = try? Data(contentsOf: url)
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    @objc private func deactivateAudioSession() {
        DispatchQueue.global(qos: .background).async {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setActive(false)
                AppLog.recorder.debug("Audio session deactivated successfully")
            } catch {
                AppLog.recorder.error("Failed to deactivate audio session: \(error)")
            }
        }
    }
}
#endif
