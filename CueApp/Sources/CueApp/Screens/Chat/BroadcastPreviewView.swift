import SwiftUI

#if os(iOS)
struct BroadcastPreviewView: View {
    @ObservedObject var viewModel: BroadcastViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Broadcast Preview")
                .font(.title)
                .bold()

            if let frameData = viewModel.frameData {
                // Frame Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Frame Information")
                        .font(.headline)

                    Group {
                        Text("Frame #: \(frameData["frameCount"] as? Int ?? 0)")
                        Text("Width: \(frameData["width"] as? Int ?? 0)")
                        Text("Height: \(frameData["height"] as? Int ?? 0)")
                        if let timestamp = frameData["timestamp"] as? TimeInterval {
                            Text("Timestamp: \(Date(timeIntervalSince1970: timestamp).formatted())")
                        }
                        if let imageData = frameData["frameData"] as? Data {
                            Text("Data Size: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file))")
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                // Image Preview
                Text("Image Preview")
                if let uiImage = viewModel.lastUIImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Text("No image available")
                        .foregroundColor(.gray)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            } else {
                Text("No frame data available")
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
}

#endif
