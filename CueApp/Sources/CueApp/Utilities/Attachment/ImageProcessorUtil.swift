//
//  ImageProcessorUtil.swift
//  CueApp
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Utility class for handling image processing operations
class ImageProcessorUtil {

    /// Maximum dimension for resizing images (on iOS)
    private static let maxDimension: CGFloat = 1000.0

    /// JPEG compression quality for resized images
    private static let resizedCompressionQuality: CGFloat = 0.7

    /// JPEG compression quality for non-resized images
    private static let standardCompressionQuality: CGFloat = 0.6

    /// Process image data for optimal size and quality
    /// - Parameters:
    ///   - imageData: Original image data
    ///   - mimeType: The MIME type of the image
    /// - Returns: A tuple containing the processed data and the resulting MIME type
    @MainActor
    static func processImageData(imageData: Data, mimeType: String) -> (data: Data, mimeType: String)? {
        #if os(iOS)
        // For iOS, apply resizing and compression
        if let uiImage = UIImage(data: imageData) {
            return processUIImage(uiImage: uiImage, originalData: imageData)
        }
        #endif

        // Default case (or macOS): use original data
        return (imageData, mimeType)
    }

    /// Determines the appropriate file extension from image data
    /// - Parameter data: The image data
    /// - Returns: The file extension (without dot)
    static func getFileExtension(from data: Data) -> String {
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

    /// Determines the MIME type from image data
    /// - Parameter data: The image data
    /// - Returns: The MIME type string
    static func getMimeType(from data: Data) -> String {
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let uti = CGImageSourceGetType(imageSource),
           let mimeType = UTType(uti as String)?.preferredMIMEType {
            return mimeType
        }

        // Default to JPEG if we can't determine
        return "image/jpeg"
    }

    /// Gets the MIME type from a file extension
    /// - Parameter fileExtension: The file extension (without dot)
    /// - Returns: The corresponding MIME type
    static func getMimeType(from fileExtension: String) -> String {
        let lowerExtension = fileExtension.lowercased()

        switch lowerExtension {
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "heic":
            return "image/heic"
        default:
            return "image/jpeg"
        }
    }

    #if os(iOS)
    /// Process a UIImage for optimal size and quality
    /// - Parameters:
    ///   - uiImage: The UIImage to process
    ///   - originalData: The original image data for size comparison
    /// - Returns: A tuple containing the processed data and the resulting MIME type
    @MainActor
    private static func processUIImage(uiImage: UIImage, originalData: Data) -> (data: Data, mimeType: String)? {
        // Calculate scale for resizing
        let scale: CGFloat

        if uiImage.size.width > uiImage.size.height {
            scale = maxDimension / uiImage.size.width
        } else {
            scale = maxDimension / uiImage.size.height
        }

        // Only resize if needed (image is larger than max dimension)
        if scale < 1.0 {
            let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            uiImage.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            if let resizedImage = resizedImage, let compressedData = resizedImage.jpegData(compressionQuality: resizedCompressionQuality) {
                print("Resized and compressed image from \(originalData.count) to \(compressedData.count) bytes")
                print("New dimensions: \(newSize.width) x \(newSize.height)")
                return (compressedData, "image/jpeg")
            }
        } else {
            // Compress without resizing
            if let compressedData = uiImage.jpegData(compressionQuality: standardCompressionQuality) {
                print("Compressed image from \(originalData.count) to \(compressedData.count) bytes")
                return (compressedData, "image/jpeg")
            }
        }

        // Fallback to original data if processing fails
        return (originalData, getMimeType(from: originalData))
    }
    #endif

    /// Creates a thumbnail image from image data
    /// - Parameter data: The image data
    /// - Returns: An optional SwiftUI Image
    @MainActor
    static func createThumbnail(from data: Data) -> Image? {
        #if os(iOS)
        if let uiImage = UIImage(data: data) {
            return Image(uiImage: uiImage)
        }
        #elseif os(macOS)
        if let nsImage = NSImage(data: data) {
            return Image(nsImage: nsImage)
        }
        #endif

        return nil
    }

    /// Creates a thumbnail image from a file URL
    /// - Parameter url: The file URL
    /// - Returns: An optional SwiftUI Image
    @MainActor
    static func createThumbnail(from url: URL) -> Image? {
        #if os(iOS)
        if let uiImage = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: uiImage)
        }
        #elseif os(macOS)
        if let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        #endif

        return nil
    }
}
