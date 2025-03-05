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
    var base64String: String?
    var imageData: Data?
    #if os(macOS)
    var thumbnail: Image?
    #else
    var thumbnail: Image?
    #endif
}

protocol AttachmentServiceProtocol {
    func pickFile(of type: AttachmentType) async throws -> Attachment?
    func pickImage(from source: ImageSource) async throws -> Attachment?
    func generateThumbnail(for attachment: Attachment) async -> Image?
    func delete(attachment: Attachment) async
}

struct FileData {
    let fileName: String
    let content: String
}

extension Attachment {
    var mimeType: String {
        let fileExtension: String
        if self.imageData != nil {
            fileExtension = self.name.components(separatedBy: ".").last?.lowercased() ?? "jpg"
        } else if self.type == .image {
            fileExtension = url.pathExtension.lowercased()
        } else {
            return ""
        }

        let mimeType: String

        switch fileExtension {
        case "png":
            mimeType = "image/png"
        case "gif":
            mimeType = "image/gif"
        case "heic":
            mimeType = "image/heic"
        default:
            mimeType = "image/jpeg"
        }
        return mimeType
    }
}
