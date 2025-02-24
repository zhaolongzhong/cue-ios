import Foundation
import SwiftUI
import UniformTypeIdentifiers
import PDFKit
#if os(macOS)
import AppKit
#endif
import CueOpenAI

struct AttachmentUtil {
    // Existing text extraction function
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
        guard let image = NSImage(contentsOfFile: attachment.url.path) else {
            throw NSError(domain: "AttachmentUtil", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
        }

        // Process the image: resize and convert to base64
        let maxDimension: CGFloat = 1024
        var newSize = image.size

        if newSize.width > maxDimension || newSize.height > maxDimension {
            let ratio = min(maxDimension / newSize.width, maxDimension / newSize.height)
            newSize = NSSize(width: newSize.width * ratio, height: newSize.height * ratio)
        }

        guard let resizedImage = image.resized(to: newSize),
              let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "AttachmentUtil", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to resize or compress image"])
        }

        // Convert to base64
        let base64String = imageData.base64EncodedString()
        let base64Url = "data:image/jpeg;base64,\(base64String)"

        // Create image content block
        return OpenAI.ContentBlock(
            type: .imageUrl,
            imageUrl: OpenAI.ImageURL(url: base64Url)
        )
        #else
        // For non-macOS platforms
        throw NSError(domain: "AttachmentUtil", code: 5, userInfo: [NSLocalizedDescriptionKey: "Image processing not supported on this platform"])
        #endif
    }

    // Function to determine if attachment is processable
    static func canProcess(attachment: Attachment) -> Bool {
        switch attachment.type {
        case .document:
            let ext = attachment.url.pathExtension.lowercased()
            return ["pdf", "rtf", "txt", "md"].contains(ext)
        case .image:
            #if os(macOS)
            return true
            #else
            return false
            #endif
        }
    }

    // Helper function to get file size (useful for logging/debugging)
    static func getFileSize(url: URL) -> Int? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int
        } catch {
            return nil
        }
    }
}

#if os(macOS)
import AppKit

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage? {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        let rect = NSRect(origin: .zero, size: newSize)
        self.draw(in: rect, from: NSRect(origin: .zero, size: self.size), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    func jpegData(compressionQuality: CGFloat = 0.7) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData)
        else { return nil }
        let properties: [NSBitmapImageRep.PropertyKey: Any] = [.compressionFactor: compressionQuality]
        return rep.representation(using: .jpeg, properties: properties)
    }
}
#endif
