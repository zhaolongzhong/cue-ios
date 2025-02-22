import SwiftUI

#if os(macOS)
struct WindowSizeMonitor: NSViewRepresentable {
    let onSizeChange: @MainActor (CGSize) -> Void

    class Coordinator: NSObject {
        let onSizeChange: @MainActor (CGSize) -> Void

        init(onSizeChange: @MainActor @escaping (CGSize) -> Void) {
            self.onSizeChange = onSizeChange
        }

        @MainActor @objc func windowDidResize(_ notification: Notification) {
            guard let window = notification.object as? NSWindow else { return }
            let size = window.frame.size

            Task { @MainActor in
                self.onSizeChange(size)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSizeChange: onSizeChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: nil
        )

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
