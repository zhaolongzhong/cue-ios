//
//  VoiceChatButton.swift
//  CueApp
//
import SwiftUI

struct VoiceChatButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "waveform")
                .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .withIconHover()
    }
}
