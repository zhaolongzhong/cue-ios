//
//  AttachmentsListView.swift
//  CueApp
//

import SwiftUI

struct AttachmentsListView: View {
    let attachments: [Attachment]
    let onRemove: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments.indices, id: \.self) { index in
                    AttachmentItemView(
                        attachment: attachments[index],
                        onRemove: { onRemove(index) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct AttachmentItemView: View {
    let attachment: Attachment
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Text(attachment.name)
                .lineLimit(1)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
        )
    }
}
