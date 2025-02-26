import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
import PhotosUI
#endif

@MainActor
final class AttachmentService: AttachmentServiceProtocol {
    #if os(macOS)
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
    #else
    // iOS implementation
    func pickImage(from source: ImageSource) async throws -> Attachment? {
        return try await withCheckedThrowingContinuation { continuation in
            var configuration = PHPickerConfiguration()
            configuration.filter = .images

            let picker = PHPickerViewController(configuration: configuration)

            // Get the key window using the newer UIWindowScene API
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let controller = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController

            // Capture self strongly in the completion handler since the continuation owns the lifetime
            // of this closure and we need self to remain alive until completion
            let pickerDelegate = ImagePickerDelegate(completion: { url in

                if let url = url {
                    // Move the attachment creation to the MainActor context
                    Task { @MainActor in
                        let attachment = self.createAttachment(from: url, type: .image)
                        continuation.resume(returning: attachment)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            })

            picker.delegate = pickerDelegate
            controller?.present(picker, animated: true)
        }
    }

    func pickFile(of type: AttachmentType) async throws -> Attachment? {
        return try await withCheckedThrowingContinuation { continuation in
            let documentTypes = type.allowedTypes.map { $0.identifier }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: type.allowedTypes)

            let controller = UIApplication.shared.windows.first?.rootViewController

            let pickerDelegate = FilePickerDelegate(completion: { url in

                if let url = url {
                    // Move the attachment creation to the MainActor context
                    Task { @MainActor in
                        let attachment = self.createAttachment(from: url, type: type)
                        continuation.resume(returning: attachment)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            })

            controller?.present(picker, animated: true)
        }
    }

    func generateThumbnail(for attachment: Attachment) async -> Image? {
        // If attachment is an image, load and wrap it in a SwiftUI Image.
        guard attachment.type == .image,
              let uiImage = UIImage(contentsOfFile: attachment.url.path)
        else { return nil }
        return Image(uiImage: uiImage)
    }
    #endif

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

#if os(iOS)
// Helper delegate classes for iOS
class FilePickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        super.init()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(nil)
    }
}

class ImagePickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private let completion: @Sendable (URL?) -> Void

    init(completion: @escaping @Sendable (URL?) -> Void) {
        self.completion = completion
        super.init()
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let itemProvider = results.first?.itemProvider,
              itemProvider.canLoadObject(ofClass: UIImage.self) else {
            completion(nil)
            return
        }

        let completionCopy = self.completion

        itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
            guard let image = image as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.8) else {
                DispatchQueue.main.async {
                    completionCopy(nil)
                }
                return
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")

            do {
                try data.write(to: tempURL)
                DispatchQueue.main.async {
                    self?.completion(tempURL)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.completion(nil)
                }
            }
        }
    }
}
#endif
