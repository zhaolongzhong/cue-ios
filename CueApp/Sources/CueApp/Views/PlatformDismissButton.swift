import SwiftUI

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let action: (() -> Void)?
    var iconSize: CGFloat = 16
    var tappablePadding: CGFloat = 8

    init(action: (() -> Void)? = nil) {
        self.action = action
    }

    var body: some View {
        Button {
            #if os(macOS)
            // Store window reference before any actions
            let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow })

            // Execute cleanup action first
            action?()

            // Schedule window closure and dismiss for next run loop
            DispatchQueue.main.async { [weak window] in
                // Hide window immediately
                window?.orderOut(nil)

                // Schedule final cleanup for next run loop
                DispatchQueue.main.async {
                    window?.close()
                    dismiss()
                }
            }
            #else
            action?()
            dismiss()
            #endif
        } label: {
            #if os(iOS)
            Image(systemName: "xmark")
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .padding(tappablePadding)
                .contentShape(Rectangle())
            #else
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .semibold))
                .colorInvert()
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(Color(nsColor: .textColor).opacity(0.2))
                )
                .contentShape(Circle())
            #endif
        }
        .buttonStyle(.plain)
        .frame(width: 36, height: 36)
        .keyboardShortcut(.cancelAction)
        #if os(macOS)
        .keyboardShortcut(.escape, modifiers: [])
        #endif
    }
}
