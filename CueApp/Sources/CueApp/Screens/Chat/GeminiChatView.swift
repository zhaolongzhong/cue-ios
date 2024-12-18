import SwiftUI
import ReplayKit
import BroadcastShared

public struct GeminiChatView: View {
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isInputFocused: Bool
    @Namespace private var bottomID
    @State private var showingToolsList = false
    @StateObject private var manager = LiveAPIWebSocketManager() // Initialize here
    @Environment(\.scenePhase) private var scenePhase
    private let apiKey: String
    @StateObject private var broadcastVM = BroadcastViewModel()

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
            }
            
            // Embed the BroadcastPickerView as a visible button
            HStack {
                Spacer()
                BroadcastPickerView(preferredExtension: "ai.nextlabs.app.BroadcastExtension")
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.2)) // More visible background
                    .border(Color.blue, width: 1) // Add border to see frame
                    .onTapGesture {
                        print("🎥 View tapped!")
                    }
            }
            .background(Color.gray.opacity(0.5))
            .padding()
            Spacer()
            if let frameData = broadcastVM.frameData {
                VStack(alignment: .leading) {
                    Text("Frame Size: \(frameData["width"] as? Int ?? 0)x\(frameData["height"] as? Int ?? 0)")
                    Text("Frame Count: \(frameData["frameCount"] as? Int ?? 0)")
                    if let timestamp = frameData["timestamp"] as? TimeInterval {
                        Text("Last Update: \(Date(timeIntervalSince1970: timestamp), style: .time)")
                    }
                }
                .padding()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                print("GeminiChatView App entering background")
                // Handle background state if needed
            case .active:
                print("GeminiChatView App becoming active")
                // Handle active state
            case .inactive:
                print("GeminiChatView App becoming inactive")
                // Handle inactive state
            @unknown default:
                break
            }
        }
        // Add this somewhere in your view
        .onAppear {
            print("📱 GeminiChatView: Testing SharedDataManager")
            let testManager = SharedDataManager.shared
            testManager.saveFrameData(width: 100, height: 100, frameCount: -1)
            if let testData = testManager.getLastFrameData() {
                print("✅ GeminiChatView: Test data retrieved: \(testData)")
            } else {
                print("❌ GeminiChatView: Failed to retrieve test data")
            }
        }
    }
}
