//
//  MessageRowView.swift
//

import SwiftUI
import OpenAI

struct MessageRowView: View {
    let message: Item.Message
    @ObservedObject var audioPlayer: AudioStreamPlayer

    var body: some View {
        VStack(alignment: .leading) {
            Text(message.role.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(message.content, id: \.id) { content in
                switch content {
                case .text(let text), .input_text(let text):
                    Text(text)
                case .audio(let audio), .input_audio(let audio):
                    if let transcript = audio.transcript {
                        Text(transcript)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
