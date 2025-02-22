import SwiftUI
import Combine

@MainActor
class RichTextFieldViewModel: ObservableObject {
    @Published var attachments: [Attachment] = []
    
    private let attachmentService: AttachmentServiceProtocol
    
    init(attachmentService: AttachmentServiceProtocol = AttachmentService()) {
        self.attachmentService = attachmentService
    }
    
    func handleAttachment(type: AttachmentType) async {
        do {
            guard let attachment = try await attachmentService.pickFile(of: type) else {
                return
            }
            attachments.append(attachment)
        } catch {
            print("Error picking file: \(error)")
        }
    }
    
    func handleImage(from source: ImageSource) async {
        do {
            guard let attachment = try await attachmentService.pickImage(from: source) else {
                return
            }
            attachments.append(attachment)
        } catch {
            print("Error picking image: \(error)")
        }
    }
    
    func removeAttachment(_ attachment: Attachment) {
        Task {
            await attachmentService.delete(attachment)
            attachments.removeAll { $0.id == attachment.id }
        }
    }
}