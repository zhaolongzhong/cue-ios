import SwiftUI
import Dependencies
import CueCommon
import CueOpenAI

struct LiveIndicatorView: View {
    @Dependency(\.realtimeClient) public var realtimeClient
    @State private var voiceState: VoiceChatState = .idle
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(isAnimating ? 0.5 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Text("Live")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(voiceState == .active ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: voiceState)
        .onAppear {
            isAnimating = true
            Task { @MainActor in
                for await state in realtimeClient.voiceChatStatePublisher.values {
                    voiceState = state
                }
            }
        }
    }
}
