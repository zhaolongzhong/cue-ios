import SwiftUI
import UniformTypeIdentifiers

enum AttachmentType {
    case image
    case document

    var allowedTypes: [UTType] {
        switch self {
        case .image:
            return [.image, .jpeg, .png]
        case .document:
            return [.text, .plainText, .pdf, .rtf]
        }
    }
}

enum ImageSource {
    case photoLibrary
    case camera
}

struct Attachment: Identifiable {
    let id = UUID()
    let url: URL
    let type: AttachmentType
    let name: String
    let size: Int64
    let createdAt: Date

    var thumbnail: Image?
}

protocol AttachmentServiceProtocol {
    func pickFile(of type: AttachmentType) async throws -> Attachment?
    func pickImage(from source: ImageSource) async throws -> Attachment?
    func generateThumbnail(for attachment: Attachment) async -> Image?
    func delete(attachment: Attachment) async
}
