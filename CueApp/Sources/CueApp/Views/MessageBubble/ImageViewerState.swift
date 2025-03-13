//
//  ImageViewerState.swift
//  CueApp
//

import SwiftUI

#if os(iOS)
class ImageViewerState: ObservableObject {
    @MainActor static let shared = ImageViewerState()

    @Published var isPresented: Bool = false
    @Published var imageURL: String?

    func showImage(url: String) {
        self.imageURL = url
        self.isPresented = true
    }

    func dismiss() {
        self.isPresented = false
    }
}

struct ImageViewerModifier: ViewModifier {
    @StateObject private var viewerState = ImageViewerState.shared

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .fullScreenCover(isPresented: $viewerState.isPresented) {
                if let url = viewerState.imageURL {
                    GlobalImageViewer(dataURL: url)
                }
            }
            #endif
    }
}

extension View {
    func withImageViewer() -> some View {
        self.modifier(ImageViewerModifier())
    }
}
#endif

#if os(macOS)
@MainActor
class ImageViewerState: ObservableObject {
    static let shared = ImageViewerState()

    @Published var isPresented: Bool = false
    @Published var imageURL: String?

    func showImage(url: String) {
        self.imageURL = url
        openInCustomWindow(url: url)
    }

    func dismiss() {
        self.isPresented = false
    }

    // Function to open image in a custom transparent window
    private func openInCustomWindow(url: String) {
        guard let dataComponents = url.components(separatedBy: ",").last,
              let imageData = Data(base64Encoded: dataComponents),
              let nsImage = NSImage(data: imageData) else {
            print("Failed to decode image data")
            return
        }

        let windowID = "imageViewer-\(UUID().uuidString)"

        // Create a borderless, transparent window
        let window = CustomImageWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless, .fullSizeContentView, .resizable, .closable],
            backing: .buffered,
            defer: false
        )

        window.identifier = NSUserInterfaceItemIdentifier(windowID)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.center()

        let hostingController = NSHostingController(
            rootView: ImageViewerWindowContent(image: nsImage, windowToClose: window)
        )

        window.contentView = hostingController.view

        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 20
            contentView.layer?.masksToBounds = true
        }

        // Make the window key and order front
        window.makeKeyAndOrderFront(nil)
    }
}

class CustomImageWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            self.close()
        } else {
            super.keyDown(with: event)
        }
    }
}

struct ImageViewerWindowContent: View {
    let image: NSImage
    let windowToClose: NSWindow
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    shareImage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Share Image")

                Button {
                    openInPreview()
                } label: {
                    Text("Open in Preview")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Open in Preview app")

                Button {
                    windowToClose.close()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.8))
                        .padding(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            )

            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)

                // Image with border
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1),
                                lineWidth: 1
                            )
                            .padding(.all, 2)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 32)
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func shareImage() {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "share-\(UUID().uuidString).png"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        // Save the image to the temporary file
        if let bitmapRep = image.representations.first as? NSBitmapImageRep,
           let data = bitmapRep.representation(using: .png, properties: [:]) {
            do {
                try data.write(to: fileURL)

                let sharingServicePicker = NSSharingServicePicker(items: [fileURL])

                // Show the picker from the window
                if windowToClose.contentView != nil,
                   let view = NSApplication.shared.windows.first(where: { $0 == windowToClose })?.contentView {
                    sharingServicePicker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
                }
            } catch {
                print("Failed to share image: \(error.localizedDescription)")
            }
        }
    }

    private func openInPreview() {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "preview-\(UUID().uuidString).png"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        // Save the image to the temporary file
        if let bitmapRep = image.representations.first as? NSBitmapImageRep,
           let data = bitmapRep.representation(using: .png, properties: [:]) {
            do {
                try data.write(to: fileURL)
                NSWorkspace.shared.open(fileURL)
            } catch {
                print("Failed to open in Preview: \(error.localizedDescription)")
            }
        }
    }
}
#endif
