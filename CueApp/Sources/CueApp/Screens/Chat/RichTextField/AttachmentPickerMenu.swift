import SwiftUI
#if os(iOS)
import PhotosUI
#endif

struct AttachmentPickerMenu: View {
    var onAttachmentPicked: ((Attachment) -> Void)?
    private let attachmentService = AttachmentService()

    #if os(iOS)
    @State private var imageSelection: PhotosPickerItem?
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    #endif

    var body: some View {
        #if os(macOS)
        // macOS implementation with Menu
        HoverButton {
            Menu {
                Button {
                    Task {
                        if let attachment = try? await attachmentService.pickFile(of: .document) {
                            onAttachmentPicked?(attachment)
                        }
                    }
                } label: {
                    Label("Upload File", systemImage: "folder")
                }

                Button {
                    Task {
                        if let attachment = try? await attachmentService.pickImage(from: .photoLibrary) {
                            onAttachmentPicked?(attachment)
                        }
                    }
                } label: {
                    Label("Upload Photo", systemImage: "photo")
                }
            } label: {
                Label("", systemImage: "plus")
                    .imageScale(.large)
                    .background(
                        Circle()
                            .strokeBorder(
                                Color.primary.opacity(0.2),
                                lineWidth: 0.8
                            )
                    )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        #else
        // iOS implementation with separate buttons
        HoverButton {
            Menu {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Upload Photo", systemImage: "photo")
                }
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Upload File", systemImage: "folder")
                }
            } label: {
                Label("", systemImage: "plus")
                    .imageScale(.large)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        // Direct photo picker for iOS
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $imageSelection,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: imageSelection) { newValue in
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
        #endif
    }
}
