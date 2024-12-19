import SwiftUI
import ReplayKit

#if os(iOS)
struct BroadcastPickerView: UIViewRepresentable {
    let preferredExtension: String

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        print("🎥 Creating BroadcastPickerView")
        // Set a specific frame
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = preferredExtension

        print("🎥 Preferred extension: \(preferredExtension)")
        print("🎥 Picker frame: \(picker.frame)")

        if let button = picker.subviews.first as? UIButton {
            print("🎥 Found button in picker")
            button.imageView?.tintColor = .systemBlue
            button.isEnabled = true
            button.isUserInteractionEnabled = true

            // Force layout
            button.frame = picker.bounds
            button.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            print("🎥 Button frame after layout: \(button.frame)")
        }

        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        print("🎥 UpdateUIView called")
        // Force layout if needed
        uiView.setNeedsLayout()
        uiView.layoutIfNeeded()
    }
}
#endif
