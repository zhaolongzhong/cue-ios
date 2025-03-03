//
//  VoiceChatButton.swift
//  CueApp
//
import SwiftUI

struct VoiceChatButton: View {
    let action: () -> Void

    var body: some View {
        HoverButton {
            Button(action: action) {
                Image(systemName: "waveform")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
        }
    }
}
