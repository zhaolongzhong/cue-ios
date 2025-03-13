import SwiftUI
#if os(iOS)
import PhotosUI
import UIKit
import UniformTypeIdentifiers
#endif

struct AttachmentPickerMenu: View {
    var onAttachmentPicked: ((Attachment) -> Void)?
    private let attachmentService = AttachmentService()

    #if os(iOS)
    @State private var imageSelection: PhotosPickerItem?
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    #endif

    var body: some View {
        #if os(macOS)
        Menu {
            Button {
                Task {
                    if let attachment = try? await attachmentService.pickFile(of: .document) {
                        onAttachmentPicked?(attachment)
                    }
                }
            } label: {
                Label("Upload Files", systemImage: "folder")
            }

            Button {
                Task {
                    if let attachment = try? await attachmentService.pickImage(from: .photoLibrary) {
                        onAttachmentPicked?(attachment)
                    }
                }
            } label: {
                Label("Upload Photos", systemImage: "photo")
            }
        } label: {
            Image(systemName: "plus")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .withIconHover()
        #else
        Menu {
            Button {
                showDocumentPicker = true
            } label: {
                Label("Attach Files", systemImage: "folder")
            }
            Button {
                showCameraPicker = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
            Button {
                showPhotoPicker = true
            } label: {
                Label("Attach Photos", systemImage: "photo")
            }
        } label: {
            Label("", systemImage: "plus")
                .imageScale(.large)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        // Photo picker for iOS
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $imageSelection,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: imageSelection) { _, newValue in
            if let item = newValue {
                Task {
                    if let attachment = await attachmentService.processPickedImage(item: item) {
                        onAttachmentPicked?(attachment)
                    }
                    // Reset selection after processing
                    imageSelection = nil
                }
            }
        }
        // Camera UI
        .sheet(isPresented: $showCameraPicker) {
            CameraView { uiImage in
                if let image = uiImage {
                    Task {
                        if let attachment = await attachmentService.processCameraImage(uiImage: image) {
                            onAttachmentPicked?(attachment)
                        }
                    }
                }
                showCameraPicker = false
            }
        }
        // Document Picker UI
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                if let fileURL = url {
                    Task {
                        if let attachment = await attachmentService.processPickedFile(url: fileURL) {
                            onAttachmentPicked?(attachment)
                        }
                    }
                }
                showDocumentPicker = false
            }
        }
        #endif
    }
}

#if os(iOS)
// Camera view to handle camera capture
struct CameraView: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var onImageCaptured: (UIImage?) -> Void

        init(onImageCaptured: @escaping (UIImage?) -> Void) {
            self.onImageCaptured = onImageCaptured
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            onImageCaptured(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageCaptured(nil)
        }
    }
}

// Document picker view to handle file selection
struct DocumentPickerView: UIViewControllerRepresentable {
    var onDocumentPicked: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Set up allowed document types (you can customize this based on your needs)
        let supportedTypes: [UTType] = [.pdf, .text, .image, .movie, .audio, .spreadsheet, .presentation, .zip, .archive]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentPicked: onDocumentPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onDocumentPicked: (URL?) -> Void

        init(onDocumentPicked: @escaping (URL?) -> Void) {
            self.onDocumentPicked = onDocumentPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onDocumentPicked(nil)
                return
            }

            // Start accessing the security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()

            // Make sure you release the security-scoped resource when you're done
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Create a local copy of the file in your app's temporary directory
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = url.lastPathComponent
            let localURL = tempDir.appendingPathComponent(fileName)

            do {
                // Remove any existing file at the destination
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }

                // Copy the file to the temporary directory
                try FileManager.default.copyItem(at: url, to: localURL)

                // Pass the local URL to the callback
                onDocumentPicked(localURL)
            } catch {
                print("Error copying file: \(error)")
                onDocumentPicked(nil)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDocumentPicked(nil)
        }
    }
}
#endif

// You'll need to add this method to your AttachmentService class
@MainActor
extension AttachmentService {
    #if os(iOS)
    func processPickedFile(url: URL) async -> Attachment? {
        let name = url.lastPathComponent
        let size = fileSize(for: url)
        let createdAt = Date()

        return Attachment(
            url: url,
            type: .document,
            name: name,
            size: size,
            createdAt: createdAt,
            base64String: nil, // Documents might be large, so we don't base64 encode them
            imageData: nil,     // Not an image
            thumbnail: nil      // No thumbnail for documents
        )
    }
    #endif
}
