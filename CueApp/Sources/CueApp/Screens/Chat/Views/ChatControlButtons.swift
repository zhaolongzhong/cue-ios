import SwiftUI

struct ChatControlButtons: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Stop Button
            Button {
                viewModel.stopAssistant()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .help("Stop current task")
            
            // Reset Button
            Button {
                viewModel.resetAssistant()
            } label: {
                Label("Reset", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .help("Reset assistant state")
            
            // Retry Button
            Button {
                viewModel.retryLastMessage()
            } label: {
                Label("Retry", systemImage: "arrow.counterclockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .tint(.green)
            .help("Retry last operation")
        }
        .controlSize(.small)
    }
}