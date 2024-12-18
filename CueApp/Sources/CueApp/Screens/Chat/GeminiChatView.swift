import SwiftUI

public struct GeminiChatView: View {
    @StateObject private var viewModel: GeminiChatViewModel
    @FocusState private var isInputFocused: Bool
    @Namespace private var bottomID
    @State private var showingToolsList = false
    @State private var manager: LiveAPIWebSocketManager? = nil
    private let apiKey: String

    public init(apiKey: String) {
        self.apiKey = apiKey
        _viewModel = StateObject(wrappedValue: GeminiChatViewModel(apiKey: apiKey))
    }

    public var body: some View {
        VStack {
            List {
                Button("connect") {
                    print("connect")
                    self.manager = LiveAPIWebSocketManager()
                    Task {
                        try await self.manager?.connect(apiKey: self.apiKey)
                    }
                }
                Button("send message") {
                    print("send message")
                    Task {
                        try await manager?.sendText("Hello, how are you?")
                    }
                }
                Button("send message about model") {
                    print("send message")
                    Task {
                        try await manager?.sendText("What are your model card info? Who are you?")
                    }
                }
                Button("disconnect") {
                    print("disconnect")
                    manager?.disconnect()
                }
            }
        }
        .onAppear {
            Task {
                
            }
        }
    }
}
