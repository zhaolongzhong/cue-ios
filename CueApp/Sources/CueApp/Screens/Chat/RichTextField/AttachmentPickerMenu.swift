//
//  AttachmentPickerMenu.swift
//  CueApp
//

import SwiftUI

struct AttachmentPickerMenu: View {
    var onAttachmentPicked: ((Attachment) -> Void)?
    private let attachmentService = AttachmentService()

    var body: some View {
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
//                Button {
//                    Task {
//                        if let attachment = try? await attachmentService.pickImage(from: .photoLibrary) {
//                            onAttachmentPicked?(attachment)
//                        }
//                    }
//                } label: {
//                    Label("Upload Photo", systemImage: "photo")
//                }
            } label: {
                Label("", systemImage: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .imageScale(.large)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
