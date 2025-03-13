//
//  UserMessageView.swift
//  CueApp
//
import SwiftUI

struct UserMessageView: View {
    let segments: [CueChatMessage.MessageSegment]
    @StateObject private var viewerState = ImageViewerState.shared

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(segments.indices, id: \.self) { index in
                switch segments[index] {
                case .text(let content):
                    Text(content)
                        .padding(10)
                        .background(AppTheme.Colors.Message.userBubble.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                case .image(let imageFileData):
                    AdaptiveImageView(dataURL: imageFileData.url)
                        .onTapGesture {
                            viewerState.showImage(url: imageFileData.url)
                        }
                default:
                    EmptyView()
                }
            }
        }
    }
}
