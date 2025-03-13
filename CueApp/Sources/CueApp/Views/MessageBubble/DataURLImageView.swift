//
//  DataURLImageView.swift
//  CueApp
//
import SwiftUI

#if os(iOS)
struct AdaptiveImageView: View {
    let dataURL: String
    @State private var image: UIImage?

    private let fixedHeight: CGFloat = 200

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(
                           height: fixedHeight)

            } else {
                ProgressView()
                    .frame(width: 200, height: fixedHeight)
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard let dataComponents = dataURL.components(separatedBy: ",").last,
              let imageData = Data(base64Encoded: dataComponents) else {
            print("Failed to decode base64 string")
            return
        }

        if let uiImage = UIImage(data: imageData) {
            DispatchQueue.main.async {
                self.image = uiImage
            }
        } else {
            print("Failed to create image from data")
        }
    }
}
#endif

#if os(macOS)
struct AdaptiveImageView: View {
    let dataURL: String
    @State private var image: NSImage?
    @State private var isPortrait: Bool = false
    @State private var isLoaded: Bool = false

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: isPortrait ? 240 : 300,
                        height: isPortrait ? 320 : 200
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 2)
            } else {
                ProgressView()
                    .frame(width: 300, height: 200)
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }

    private func loadImage() {
        guard let dataComponents = dataURL.components(separatedBy: ",").last,
              let imageData = Data(base64Encoded: dataComponents) else {
            AppLog.log.error("Failed to decode base64 string")
            return
        }

        // Create NSImage from the data
        if let nsImage = NSImage(data: imageData) {
            // Determine orientation
            let portrait = nsImage.size.height > nsImage.size.width

            DispatchQueue.main.async {
                // Update both state variables at once
                self.isPortrait = portrait
                self.image = nsImage
                self.isLoaded = true
            }
        } else {
            AppLog.log.error("Failed to create image from data")
        }
    }
}
#endif
