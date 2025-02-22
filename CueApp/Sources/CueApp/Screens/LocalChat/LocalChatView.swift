import SwiftUI

public struct LocalChatView: View {
    @StateObject private var viewModel = LocalChatViewModel()
    @State private var showingSettings = false
    @FocusState private var isFocused: Bool
    @Namespace private var bottomID
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                        }
                        // Bottom marker for scrolling
                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding(.top)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Input area
            HStack {
                TextField("Message...", text: $viewModel.newMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .disabled(viewModel.isLoading)
                
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task {
                            await viewModel.sendMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(viewModel.newMessage.isEmpty)
                }
            }
            .padding()
        }
        .navigationTitle("Local Chat")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.clearMessages()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: $viewModel.settings)
        }
    }
}

private struct MessageView: View {
    let message: LocalChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.role == .user ? "You" : "Assistant")
                    .font(.caption)
                    .foregroundColor(message.role.color)
                
                Spacer()
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(message.content)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

private struct SettingsView: View {
    @Binding var settings: LocalChatSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Server Settings") {
                    TextField("Base URL", text: $settings.baseURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    TextField("Model", text: $settings.model)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                Section {
                    Button("Reset to Default") {
                        settings = .default
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}