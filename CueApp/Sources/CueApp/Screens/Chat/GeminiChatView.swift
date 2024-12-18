import SwiftUI

public struct GeminiChatView: View {
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isInputFocused: Bool
    @Namespace private var bottomID
    @State private var showingToolsList = false
    @StateObject private var manager = LiveAPIWebSocketManager() // Initialize here
    @Environment(\.scenePhase) private var scenePhase
    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
        _viewModel = StateObject(wrappedValue: GeminiChatViewModel(apiKey: apiKey))
    }

    public var body: some View {
        VStack {
            List {
                Button("Connect") {
                    print("Connect")
                    Task {
                        do {
                            try await manager.connect(apiKey: apiKey)
                        } catch {
                            print("Failed to connect: \(error)")
                        }
                    }
                }
                Button("Send Message") {
                    print("Send Message")
                    Task {
                        do {
                            try await manager.sendText("""
                                Hey, I need you to do three things for me.

                                1. Turn on the lights
                                2. Then compute the largest prime palindrome under 100000.
                                3. Then use Google Search to look up information about the largest earthquake in California the week of Dec 5, 2024?

                                Thanks!
                                """)
                        } catch {
                            print("Failed to send message: \(error)")
                        }
                    }
                }
                Button("Send Message About Model") {
                    print("Send Message About Model")
                    Task {
                        do {
                            try await manager.sendText("What are your model card info? Who are you?")
                        } catch {
                            print("Failed to send model message: \(error)")
                        }
                    }
                }
                Button("Disconnect") {
                    print("Disconnect")
                    manager.disconnect()
                }
                
                Button("Start Screen Capture") {
                    print("Start Screen Capture")
                    Task {
                        do {
                            try await manager.startScreenCapture()
                        } catch ScreenCaptureError.permissionDenied {
                            print("Screen capture permission denied")
                        } catch {
                            print("Screen capture error: \(error.localizedDescription)")
                        }
                    }
                }
                
                Button("Stop Screen Capture") {
                    print("Stop Screen Capture")
                    Task {
                        do {
                            try await manager.stopScreenCapture()
                        } catch {
                            print("Failed to stop screen capture: \(error)")
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                print("App entering background")
                // Keep screen recording active if it's running
                if manager.isScreenCapturing {
                    Task {
                        try? await keepScreenCaptureAlive()
                    }
                }
            case .active:
                print("App becoming active")
                // Resume normal operation
            case .inactive:
                print("App becoming inactive")
            @unknown default:
                break
            }
        }
        .onAppear {
            // Initialize manager or perform additional setup if needed
        }
    }
    
    private func keepScreenCaptureAlive() async throws {
        // Request additional background execution time
        let taskID = UIApplication.shared.beginBackgroundTask {
            // Cleanup when background task expires
            Task {
                await manager.stopScreenCapture()
            }
        }
        
        // Optionally, you can store taskID if you need to end it manually
        // However, since `BackgroundTaskManager` is handling it, ensure no conflicts
    }
}
