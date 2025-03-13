//
//  MessageBubbleControlButtons.swift
//  CueApp
//
import SwiftUI

struct MessageBubbleControlButtons: View {
    let message: CueChatMessage
    @Binding var isHovering: Bool

    var body: some View {
        HStack(alignment: .center) {
            if message.isUser {
                Spacer()
                if isHovering, let createdAt = message.createdAt {
                    Text("\(createdAt.relativeDate)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            CopyButton(content: message.content.contentAsString, isVisible: isHovering)
            if !message.isUser {
                if isHovering, let createdAt = message.createdAt {
                    Text("\(createdAt.relativeDate)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }
}
