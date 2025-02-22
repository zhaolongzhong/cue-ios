import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

@MainActor
class AttachmentService: NSObject, AttachmentServiceProtocol {
    private var continuation: CheckedContinuation<Attachment?, Error>?
    
    func pickFile(of type: AttachmentType) async throws -> Attachment? {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: type.allowedTypes)
            picker.delegate = self
            picker.allowsMultipleSelection = false
            
            // Get the topmost view controller to present the picker
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(picker, animated: true)
            }
        }
    }
    
    func pickImage(from source: ImageSource) async throws -> Attachment? {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            
            // Get the topmost view controller to present the picker
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(picker, animated: true)
            }
        }
    }
    
    func generateThumbnail(for attachment: Attachment) async -> Image? {
        guard attachment.type == .image else { return nil }
        
        do {
            let data = try Data(contentsOf: attachment.url)
            if let uiImage = UIImage(data: data) {
                let thumbnail = Image(uiImage: uiImage)
                return thumbnail
            }
        } catch {
            print("Error generating thumbnail: \(error)")
        }
        return nil
    }
    
    func delete(attachment: Attachment) async {
        do {
            try FileManager.default.removeItem(at: attachment.url)
        } catch {
            print("Error deleting attachment: \(error)")
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension AttachmentService: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            continuation?.resume(returning: nil)
            return
        }
        
        // Get file attributes
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey, .nameKey, .creationDateKey])
            let attachment = Attachment(
                url: url,
                type: .document,
                name: resourceValues.name ?? url.lastPathComponent,
                size: Int64(resourceValues.fileSize ?? 0),
                createdAt: resourceValues.creationDate ?? Date()
            )
            continuation?.resume(returning: attachment)
        } catch {
            continuation?.resume(throwing: error)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        continuation?.resume(returning: nil)
    }
}

// MARK: - PHPickerViewControllerDelegate
extension AttachmentService: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let provider = results.first?.itemProvider else {
            continuation?.resume(returning: nil)
            return
        }
        
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                if let error = error {
                    self?.continuation?.resume(throwing: error)
                    return
                }
                
                guard let image = image as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.8) else {
                    self?.continuation?.resume(returning: nil)
                    return
                }
                
                // Save image to temporary directory
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "\(UUID().uuidString).jpg"
                let fileURL = tempDir.appendingPathComponent(fileName)
                
                do {
                    try data.write(to: fileURL)
                    let attachment = Attachment(
                        url: fileURL,
                        type: .image,
                        name: fileName,
                        size: Int64(data.count),
                        createdAt: Date(),
                        thumbnail: Image(uiImage: image)
                    )
                    self?.continuation?.resume(returning: attachment)
                } catch {
                    self?.continuation?.resume(throwing: error)
                }
            }
        }
    }
}