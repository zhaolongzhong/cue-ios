import SwiftUI
import BroadcastShared
@preconcurrency import Combine
import CoreImage
#if os(iOS)
@MainActor
class BroadcastViewModel: ObservableObject {
    @Published var frameData: [String: Any]?
    @Published var lastFrameImage: Data?
    @Published var lastUIImage: UIImage?

    private let dataManager = SharedDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let webSocketManager: LiveAPIWebSocketManager
    private let ciContext = CIContext()
    private var lastProcessedFrameCount: Int = -1

    init(webSocketManager: LiveAPIWebSocketManager) {
        self.webSocketManager = webSocketManager
        print("🚀 BroadcastViewModel: Initializing")
        Timer.publish(every: 0.02, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForUpdates()
            }
            .store(in: &cancellables)
    }

    private func checkForUpdates() {
        if let newData = dataManager.getLastFrameData() {
            self.frameData = newData

            // Extract frame count from the data
            guard let currentFrameCount = newData["frameCount"] as? Int,
                  currentFrameCount > lastProcessedFrameCount,
                  let frameData = newData["frameData"] as? Data else {
                return
            }

            // Process the image similarly to ScreenManager
            if let image = UIImage(data: frameData),
               let processedData = processImage(image) {
                self.lastFrameImage = processedData
                self.lastUIImage = image
                self.lastProcessedFrameCount = currentFrameCount
                print("✅ Successfully processed frame #\(currentFrameCount): \(image.size), processed size: \(processedData.count)")

                // Send to WebSocket
                Task {
                    let base64Data = processedData.base64EncodedString()
                    print("📦 Base64 data length: \(base64Data.count)")

                    let chunk = LiveAPIRealtimeInput.RealtimeInput.MediaChunk(
                        mimeType: "image/jpeg",
                        data: base64Data
                    )
                    let input = LiveAPIRealtimeInput(realtimeInput: .init(mediaChunks: [chunk]))

                    do {
                        try await webSocketManager.send(input)
                        print("📤 Sent processed frame #\(currentFrameCount) successfully")
                    } catch {
                        print("❌ Failed to send frame #\(currentFrameCount): \(error.localizedDescription)")
                    }
                }
            } else {
                print("❌ Failed to process image data for frame #\(currentFrameCount)")
            }
        }
    }

    private func processImage(_ image: UIImage) -> Data? {
        // Convert UIImage to CIImage
        guard let ciImage = CIImage(image: image) else {
            print("❌ Failed to create CIImage from UIImage")
            return nil
        }
        
        // Apply any necessary image processing (similar to ScreenManager)
        // For example, you might want to resize or adjust quality

        // Convert back to UIImage with proper orientation
        let processedImage = UIImage(ciImage: ciImage, scale: 1.0, orientation: image.imageOrientation)

        // Compress with specific quality
        return processedImage.jpegData(compressionQuality: 0.7)  // Match ScreenManager's quality
    }

    deinit {
        print("🔽 BroadcastViewModel: Deinitializing")
        cancellables.forEach { $0.cancel() }
    }
}
#endif
