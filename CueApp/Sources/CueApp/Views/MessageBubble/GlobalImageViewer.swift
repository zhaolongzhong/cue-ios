import SwiftUI
import Photos

#if os(iOS)
struct GlobalImageViewer: View {
    let dataURL: String
    @StateObject private var viewerState = ImageViewerState.shared
    @State private var image: UIImage?
    @State private var showControls: Bool = true
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var errorMessage = ""
    @State private var imageSaver: ImageSaver?

    class ImageSaver: NSObject {
        var onSuccess: () -> Void
        var onError: (Error) -> Void

        init(onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void) {
            self.onSuccess = onSuccess
            self.onError = onError
            super.init()
        }

        @objc func saveComplete(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
            if let error = error {
                onError(error)
            } else {
                onSuccess()
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
                    .padding(.vertical, 20)
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }

            // Invisible overlay for tap detection
            Color.black.opacity(0.01)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls.toggle()
                    }
                }

            if showControls {
                VStack {
                    HStack {
                        Spacer()

                        Button {
                            viewerState.dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .asIcon(foregroundColor: .white)
                                .padding()
                        }
                    }

                    Spacer()

                    if image != nil {
                        HStack {
                            Spacer()
                            Button {
                                saveImage()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                        .asIcon(foregroundColor: .white)

                                    Text("Save")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            loadImage()
        }
        .alert("Saved to Photos", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        }
        .alert("Couldn't Save Photo", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
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

    private func saveImage() {
        guard let image = image else { return }

        let saver = ImageSaver(
            onSuccess: {
                DispatchQueue.main.async {
                    self.showSaveSuccess = true
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.showSaveError = true
                }
            }
        )

        self.imageSaver = saver

        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized, .limited:
                DispatchQueue.main.async {
                    UIImageWriteToSavedPhotosAlbum(image, saver, #selector(ImageSaver.saveComplete(_:didFinishSavingWithError:contextInfo:)), nil)
                }
            case .denied, .restricted:
                DispatchQueue.main.async {
                    self.errorMessage = "Please enable photo access in Settings to save images."
                    self.showSaveError = true
                }
            case .notDetermined:
                // This shouldn't happen after the request
                break
            @unknown default:
                break
            }
        }
    }
}

#endif
