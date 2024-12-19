import SwiftUI
import AVFoundation

struct RealtimeAudioView: View {
    @StateObject private var audioService: OpenAIRealtimeAudioService
    @State private var isRecording = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    init(apiKey: String) {
        _audioService = StateObject(wrappedValue: OpenAIRealtimeAudioService(apiKey: apiKey))
    }
    
    var body: some View {
        VStack {
            // Connection status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusText)
                    .font(.caption)
            }
            .padding()
            
            Spacer()
            
            // Record button
            Button(action: toggleRecording) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(isRecording ? .red : .blue)
            }
            .disabled(audioService.connectionState == .connecting)
            
            Spacer()
        }
        .alert("Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(errorMessage ?? "An unknown error occurred")
        })
    }
    
    private var statusColor: Color {
        switch audioService.connectionState {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .red
        }
    }
    
    private var statusText: String {
        switch audioService.connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        }
    }
    
    private func toggleRecording() {
        Task {
            do {
                if isRecording {
                    await audioService.stopSession()
                } else {
                    try await audioService.startSession()
                }
                isRecording.toggle()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    RealtimeAudioView(apiKey: "your-api-key-here")
}