import Foundation
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
#if os(macOS)
import AppKit
#endif
import CueOpenAI

struct AttachmentUtil {
    static func extractText(from attachment: Attachment) async throws -> String {
        let data = try Data(contentsOf: attachment.url)
        let ext = attachment.url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let pdf = PDFDocument(data: data) else {
                throw NSError(domain: "AttachmentUtil", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid PDF"])
            }
            var fullText = ""
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i), let pageContent = page.string {
                    fullText += pageContent
                }
            }
            return fullText
        } else if ext == "rtf" {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: NSAttributedString.DocumentType.rtf]
            let attributed = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return attributed.string
        } else {
            guard let text = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "AttachmentUtil", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to decode text"])
            }
            return text
        }
    }

    static func processImage(from attachment: Attachment) async throws -> OpenAI.ContentBlock? {
        #if os(macOS)
        return try await processMacOSImage(from: attachment)
        #elseif os(iOS)
        return try await processiOSImage(from: attachment)
        #else
        throw NSError(domain: "AttachmentUtil", code: 5, userInfo: [NSLocalizedDescriptionKey: "Image processing not supported on this platform"])
        #endif
    }

    // MARK: - macOS Image Processing

    #if os(macOS)
    private static func processMacOSImage(from attachment: Attachment) async throws -> OpenAI.ContentBlock {
        let fileURL = attachment.url

        // Get file information
        let (fileSize, width, height) = try getMacOSImageInfo(fileURL: fileURL)

        // Determine content type
        let contentType = determineContentType(fileExtension: fileURL.pathExtension.lowercased())

        // Log information
        logImageInfo(name: attachment.name, width: width, height: height, fileSize: fileSize, contentType: contentType)

        // Create content block
        return try createImageContentBlock(url: fileURL, contentType: contentType)
    }

    private static func getMacOSImageInfo(fileURL: URL) throws -> (fileSize: Double, width: CGFloat, height: CGFloat) {
        // Get file size
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        let fileSizeKB = Double(fileSize) / 1024.0

        // Get image dimensions if possible
        var width: CGFloat = 0
        var height: CGFloat = 0
        if let image = NSImage(contentsOf: fileURL) {
            width = image.size.width
            height = image.size.height
        }

        return (fileSizeKB, width, height)
    }
    #endif

    // MARK: - iOS Image Processing

    #if os(iOS)
    private static func processiOSImage(from attachment: Attachment) async throws -> OpenAI.ContentBlock {
        // Get image data and information
        let (imageData, contentType, width, height, fileSize) = try getiOSImageInfo(from: attachment)

        // Log information
        logImageInfo(name: attachment.name, width: width, height: height, fileSize: fileSize, contentType: contentType)

        // Create content block from data
        return createImageContentBlockFromData(imageData: imageData, contentType: contentType)
    }

    private static func getiOSImageInfo(from attachment: Attachment) throws -> (imageData: Data, contentType: String, width: CGFloat, height: CGFloat, fileSize: Double) {
        var imageData: Data
        var width: CGFloat = 0
        var height: CGFloat = 0

        // Determine how to access the image data
        if let attachmentImageData = attachment.imageData {
            imageData = attachmentImageData
            if let uiImage = UIImage(data: imageData) {
                width = uiImage.size.width
                height = uiImage.size.height
            }
        } else if FileManager.default.fileExists(atPath: attachment.url.path) {
            guard let fileData = try? Data(contentsOf: attachment.url) else {
                throw NSError(domain: "AttachmentUtil", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"])
            }
            imageData = fileData
            if let uiImage = UIImage(data: imageData) {
                width = uiImage.size.width
                height = uiImage.size.height
            }
        } else {
            throw NSError(domain: "AttachmentUtil", code: 4, userInfo: [NSLocalizedDescriptionKey: "No image data available"])
        }

        // Calculate file size
        let fileSize = Double(imageData.count) / 1024.0

        // Determine content type
        let contentType = getiOSContentType(fileExtension: attachment.url.pathExtension.lowercased())

        return (imageData, contentType, width, height, fileSize)
    }

    private static func getiOSContentType(fileExtension: String) -> String {
        if let mimeType = UTType(filenameExtension: fileExtension)?.preferredMIMEType {
            return mimeType
        }
        return determineContentType(fileExtension: fileExtension)
    }
    #endif

    // MARK: - Common Utilities

    private static func determineContentType(fileExtension: String) -> String {
        switch fileExtension {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        default:
            #if os(iOS)
            return "image/jpeg" // Safe default for iOS
            #else
            return "image/\(fileExtension)"
            #endif
        }
    }

    private static func logImageInfo(name: String, width: CGFloat, height: CGFloat, fileSize: Double, contentType: String) {
        print("📸 Image: \(name) | \(Int(width))×\(Int(height)) | \(String(format: "%.1f", fileSize))KB | \(contentType)")
    }

    #if os(macOS)
    private static func createImageContentBlock(url: URL, contentType: String) throws -> OpenAI.ContentBlock {
        guard let imageData = try? Data(contentsOf: url) else {
            throw NSError(domain: "AttachmentUtil", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"])
        }

        return createImageContentBlockFromData(imageData: imageData, contentType: contentType)
    }
    #endif

    private static func createImageContentBlockFromData(imageData: Data, contentType: String) -> OpenAI.ContentBlock {
        let base64String = imageData.base64EncodedString()
        let dataURL = "data:\(contentType);base64,\(base64String)"

        return OpenAI.ContentBlock.imageUrl(OpenAI.ImageURL(url: dataURL, detail: "low"))
    }
}

func convertToContents(attachments: [Attachment]) async -> [OpenAI.ContentBlock] {
    var contentBlocks: [OpenAI.ContentBlock] = []

    for attachment in attachments {
        switch attachment.type {
        case .document:
            do {
                let fullText = try await AttachmentUtil.extractText(from: attachment)
                let maxCharacters = 20000
                let truncatedText = fullText.count > maxCharacters
                ? String(fullText.prefix(maxCharacters)) + " [truncated]"
                : fullText
                let prefixedText = "<file_name>\(attachment.name)</file_name>\n" + truncatedText
                let documentBlock = OpenAI.ContentBlock.text(prefixedText)
                contentBlocks.append(documentBlock)
            } catch {
                AppLog.log.error("Error when processing attachment: \(error)")
            }
        case .image:
            if let block = try? await AttachmentUtil.processImage(from: attachment) {
                contentBlocks.append(block)
            }
        }
    }

    return contentBlocks
}

func extractFileData(from text: String) -> FileData? {
    let startMarker = "<file_name>"
    let endMarker = "</file_name>"

    guard let startRange = text.range(of: startMarker),
          let endRange = text.range(of: endMarker, range: startRange.upperBound..<text.endIndex) else {
        return nil
    }

    let fileName = String(text[startRange.upperBound..<endRange.lowerBound])

    // Get the content after the file name tag
    let contentStartIndex = endRange.upperBound
    let content = String(text[contentStartIndex...])

    return FileData(fileName: fileName, content: content)
}
