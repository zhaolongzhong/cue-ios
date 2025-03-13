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

#if os(iOS)
struct AttachmentItemView: View {
    let attachment: Attachment
    let onRemove: () -> Void

    @State private var thumbnailImage: Image?

    var body: some View {

        // Thumbnail for images, icon for documents
        if attachment.type == .image {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumbnail = attachment.thumbnail {
                        // Use existing thumbnail if available
                        thumbnail
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let imageData = attachment.imageData, let uiImage = UIImage(data: imageData) {
                        // Generate thumbnail from imageData
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        // Fallback icon
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .padding(6)
                            .foregroundColor(.blue)
                    }
                }

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .asIcon()
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        } else {
            HStack(spacing: 8) {
                // Document icon
                Image(systemName: "doc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(6)
                    .foregroundColor(.blue)

                if attachment.type != .image {
                    Text(attachment.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Remove button
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
            )
        }
    }

    // Format file size to human-readable format
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
#endif

#if os(macOS)
struct AttachmentItemView: View {
    let attachment: Attachment
    let onRemove: () -> Void

    @State private var thumbnailImage: Image?

    var body: some View {
        // Thumbnail for images, icon for documents
        if attachment.type == .image {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumbnail = attachment.thumbnail {
                        // Use existing thumbnail if available
                        thumbnail
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let imageData = attachment.imageData, let nsImage = NSImage(data: imageData) {
                        // Generate thumbnail from imageData
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        // Fallback icon
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .padding(6)
                            .foregroundColor(.blue)
                    }
                }

                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .asIcon()
                }
                .buttonStyle(.plain)
                .padding(2)
            }
        } else {
            HStack(spacing: 8) {
                // Document icon
                Image(systemName: "doc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .padding(6)
                    .foregroundColor(.blue)

                if attachment.type != .image {
                    Text(attachment.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Remove button
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
            )
        }
    }

    // Format file size to human-readable format
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
#endif
