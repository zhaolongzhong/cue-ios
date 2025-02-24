import SwiftUI
import UniformTypeIdentifiers
import AppKit

@MainActor
final class AttachmentService: AttachmentServiceProtocol {
    func pickFile(of type: AttachmentType) async throws -> Attachment? {
        try await withCheckedThrowingContinuation { continuation in
            let panel = NSOpenPanel()
            panel.allowedContentTypes = type.allowedTypes
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.begin { response in
                guard response == .OK, let url = panel.url else {
                    continuation.resume(returning: nil)
                    return
                }
                let attachment = self.createAttachment(from: url, type: type)
                continuation.resume(returning: attachment)
            }
        }
    }

    func pickImage(from source: ImageSource) async throws -> Attachment? {
        // For macOS, we use NSOpenPanel to pick images regardless of source
        try await withCheckedThrowingContinuation { continuation in
            let panel = NSOpenPanel()
            panel.allowedContentTypes = AttachmentType.image.allowedTypes
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.begin { response in
                guard response == .OK, let url = panel.url else {
                    continuation.resume(returning: nil)
                    return
                }
                let attachment = self.createAttachment(from: url, type: .image)
                continuation.resume(returning: attachment)
            }
        }
    }

    func generateThumbnail(for attachment: Attachment) async -> Image? {
        // If attachment is an image, load and wrap it in a SwiftUI Image.
        guard attachment.type == .image,
              let nsImage = NSImage(contentsOf: attachment.url)
        else { return nil }
        return Image(nsImage: nsImage)
    }

    func delete(attachment: Attachment) async {
        try? FileManager.default.removeItem(at: attachment.url)
    }

    private func createAttachment(from url: URL, type: AttachmentType) -> Attachment {
        let name = url.lastPathComponent
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
        let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
        return Attachment(url: url, type: type, name: name, size: size, createdAt: createdAt, thumbnail: nil)
    }
}
