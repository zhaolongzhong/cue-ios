import SwiftUI
import ReplayKit
import BroadcastShared

public struct GeminiChatView: View {
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isInputFocused: Bool
    @Namespace private var bottomID
    @State private var showingToolsList = false
    private var manager: LiveAPIWebSocketManager
    @Environment(\.scenePhase) private var scenePhase
    private let apiKey: String
    #if os(iOS)
    @StateObject private var broadcastVM: BroadcastViewModel
    #endif

    public init(apiKey: String, liveAPIWebSocketManager: LiveAPIWebSocketManager) {
        self.apiKey = apiKey
        self.manager = liveAPIWebSocketManager
        _viewModel = StateObject(wrappedValue: GeminiChatViewModel(apiKey: apiKey))
        #if os(iOS)
        _broadcastVM = StateObject(wrappedValue: BroadcastViewModel(webSocketManager: liveAPIWebSocketManager))
        #endif
    }

    public var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 12) {
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
                    .buttonStyle(.bordered)

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
                    .buttonStyle(.bordered)

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
                    .buttonStyle(.bordered)

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

                    Button("Disconnect") {
                        print("Disconnect")
                        manager.disconnect()
                    }
                    .buttonStyle(.bordered)

                    #if os(iOS)
                    BroadcastPreviewView(viewModel: broadcastVM)
                    #endif
                }
                .padding()

            }

            // Embed the BroadcastPickerView as a visible button
            #if os(iOS)
            HStack {
                Spacer()
                BroadcastPickerView(preferredExtension: "ai.nextlabs.app.BroadcastExtension")
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.2))
                    .border(Color.blue, width: 1)
                    .onTapGesture {
                        print("🎥 View tapped!")
                    }
            }
            .background(Color.gray.opacity(0.5))
            .padding()

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
            #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                print("GeminiChatView App entering background")
            case .active:
                print("GeminiChatView App becoming active")
            case .inactive:
                print("GeminiChatView App becoming inactive")
            @unknown default:
                break
            }
        }
    }
}
