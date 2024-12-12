import SwiftUI
import CueOpenAI

public struct OpenAIChatView: View {
    @StateObject private var viewModel: OpenAIChatViewModel
    @FocusState private var isInputFocused: Bool
    @Namespace private var bottomID
    @State private var showingToolsList = false

    public init(apiKey: String) {
        _viewModel = StateObject(wrappedValue: OpenAIChatViewModel(apiKey: apiKey))
    }

    public var body: some View {
        VStack {
            messageList
            inputField
        }
        .onAppear {
            Task {
                await viewModel.startServer()
            }
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .sheet(isPresented: $showingToolsList) {
            ToolsListView(tools: viewModel.availableTools)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages, id: \.id) { message in
                        MessageBubble(role: message.role, content: message.content)
                    }
                    // Invisible marker view at bottom
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding()
            }
            #if os(iOS)
           .simultaneousGesture(DragGesture().onChanged { _ in
               UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
           })
           #endif
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }

    private var inputField: some View {
        HStack {
            #if os(macOS)
            RoundedTextField(
                placeholder: "Type a message...",
                text: $viewModel.newMessage,
                isDisabled: viewModel.isLoading
            ) {
                await viewModel.sendMessage()
            }
            #else
            TextField("Type a message...", text: $viewModel.newMessage)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(viewModel.isLoading)
                .focused($isInputFocused)
            #endif

            if viewModel.availableTools.count > 0 {
                Button {
                    showingToolsList = true
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "hammer")
                            .font(.system(size: 12))
                            .foregroundColor(Color.secondary)
                            .background(Color.clear)
                        Text("\(viewModel.availableTools.count)").foregroundColor(Color.secondary)
                    }
                }
            }

            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
        .padding()
    }
}
