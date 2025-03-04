import Foundation
import UniformTypeIdentifiers
import ImageIO
import SwiftUI
#if os(iOS)
import PhotosUI
#endif

@MainActor
final class AttachmentService: AttachmentServiceProtocol {

    // Helper function to get file size
    private func fileSize(for url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[FileAttributeKey.size] as? Int64 ?? 0
        } catch {
            print("Error getting file size: \(error)")
            return 0
        }
    }

    #if os(iOS)
    // For iOS: Converting PhotosPickerItem to Attachment
    private func createAttachment(from item: PhotosPickerItem, type: AttachmentType) async -> Attachment? {
        // Load the transferable data
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            print("Failed to load transferable data from PhotosPickerItem")
            return nil
        }

        // Generate a safe filename (PhotosPicker item identifiers often contain paths that can't be used directly)
        let fileExtension = getFileExtension(from: data)
        let uniqueFilename = "photo-\(UUID().uuidString).\(fileExtension)"

        let size = Int64(data.count)
        let createdAt = Date()
        let base64String = data.base64EncodedString()
        var mimeType: String?
        var image: Image?

        // Create CGImageSource to detect MIME type
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil) {
            if let uti = CGImageSourceGetType(imageSource) {
                mimeType = UTType(uti as String)?.preferredMIMEType
                print("Detected MIME type: \(String(describing: mimeType)) for \(uniqueFilename)")
            }
        }

        // Create thumbnail
        if let uiImage = UIImage(data: data) {
            image = Image(uiImage: uiImage)
        }

        print("Creating attachment from PhotosPickerItem: name=\(uniqueFilename), data size=\(data.count)")

        // Create a temporary URL for the data - using a safe path with just the filename
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(uniqueFilename)

        do {
            try data.write(to: fileURL)
            print("Successfully saved temporary file at: \(fileURL.path)")

            return Attachment(
                url: fileURL,
                type: type,
                name: uniqueFilename,
                size: size,
                createdAt: createdAt,
                base64String: base64String,
                imageData: data,
                thumbnail: image
            )
        } catch {
            print("Error saving temporary file: \(error)")

            // Even if saving to temporary file fails, we can still return an attachment with the data in memory
            return Attachment(
                url: URL(string: "memory://\(uniqueFilename)")!, // Dummy URL since file saving failed
                type: type,
                name: uniqueFilename,
                size: size,
                createdAt: createdAt,
                base64String: base64String,
                imageData: data,
                thumbnail: image
            )
        }
    }

    // Helper to determine file extension from image data
    private func getFileExtension(from data: Data) -> String {
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let uti = CGImageSourceGetType(imageSource),
           let mimeType = UTType(uti as String)?.preferredMIMEType {

            if mimeType.contains("jpeg") || mimeType.contains("jpg") {
                return "jpg"
            } else if mimeType.contains("png") {
                return "png"
            } else if mimeType.contains("gif") {
                return "gif"
            } else if mimeType.contains("heic") {
                return "heic"
            }
        }

        // Default to jpg if we can't determine the type
        return "jpg"
    }
    #endif

    // Helper function to create attachment from URL
    private func createAttachment(from url: URL, type: AttachmentType) async -> Attachment? {
        let name = url.lastPathComponent
        let size = fileSize(for: url)
        let createdAt = Date()
        var base64String: String?
        var imageData: Data?
        var image: Image?
        var mimeType: String?

        if type == .image {
            do {
                // Download image data once
                let data = try Data(contentsOf: url)

                // Store the raw data
                imageData = data

                // Encode image data to Base64
                base64String = data.base64EncodedString()

                // Create CGImageSource from data
                guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                    print("Could not create CGImageSource from data")
                    return nil
                }

                // Get MIME type
                if let uti = CGImageSourceGetType(imageSource) {
                    mimeType = UTType(uti as String)?.preferredMIMEType
                    print("Detected MIME type: \(String(describing: mimeType)) for \(name)")
                }

                // Create thumbnail
                #if os(macOS)
                if let nsImage = NSImage(contentsOf: url) {
                    image = Image(nsImage: nsImage)
                }
                #else
                if let uiImage = UIImage(contentsOfFile: url.path) {
                    image = Image(uiImage: uiImage)
                }
                #endif

                print("Image data size: \(data.count), base64 length: \(base64String?.count ?? 0)")

            } catch {
                print("Error processing image: \(error)")
            }
        }

        print("Creating attachment: name=\(name), imageData=\(imageData != nil ? "present" : "nil"), base64=\(base64String != nil ? "present" : "nil")")

        return Attachment(
            url: url,
            type: type,
            name: name,
            size: size,
            createdAt: createdAt,
            base64String: base64String,
            imageData: imageData,
            thumbnail: image
        )
    }

    func pickFile(of type: AttachmentType) async throws -> Attachment? {
        try await withCheckedThrowingContinuation { continuation in
            #if os(macOS)
            let panel = NSOpenPanel()
            panel.allowedContentTypes = type.allowedTypes
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.begin { response in
                guard response == .OK, let url = panel.url else {
                    continuation.resume(returning: nil)
                    return
                }
                Task {
                  let attachment = await self.createAttachment(from: url, type: type)
                  continuation.resume(returning: attachment)
                }
            }
            #else
            // For iOS, use UIDocumentPickerViewController for files
            // However, this is typically handled by a different SwiftUI view
            // that would present the document picker and then call back to this service
            continuation.resume(returning: nil)
            #endif
        }
    }

    func pickImage(from source: ImageSource) async throws -> Attachment? {
        // For macOS, we use NSOpenPanel to pick images regardless of source
        try await withCheckedThrowingContinuation { continuation in
            #if os(macOS)
            let panel = NSOpenPanel()
            panel.allowedContentTypes = AttachmentType.image.allowedTypes
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.begin { response in
                guard response == .OK, let url = panel.url else {
                    continuation.resume(returning: nil)
                    return
                }
              Task {
                let attachment = await self.createAttachment(from: url, type: .image)
                continuation.resume(returning: attachment)
              }
            }
            #elseif os(iOS)
            // For iOS, the PhotosPicker would typically be presented in a SwiftUI view
            // This method would be called with the selected PhotosPickerItem
            // We'll return nil for now, as the actual selection happens in the UI layer
            continuation.resume(returning: nil)
            #endif
        }
    }

    #if os(iOS)
    // New method specifically for iOS to handle PhotosPickerItem
    func processPickedImage(item: PhotosPickerItem) async -> Attachment? {
        return await createAttachment(from: item, type: .image)
    }
    #endif

    func generateThumbnail(for attachment: Attachment) async -> Image? {
        return attachment.thumbnail // Thumbnails are already generated when creating attachment
    }

    func delete(attachment: Attachment) async {
        // Implementation for deleting attachment if needed
        // This depends on where attachments are stored and how deletion should be handled
        print("Delete attachment \(attachment.name)")
    }
}
