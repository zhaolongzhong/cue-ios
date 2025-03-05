import SwiftUI

#if os(macOS)
struct MacHeader: View {
    let title: String
    let onDismiss: (() -> Void)?

    init(title: String, onDismiss: (() -> Void)? = nil) {
        self.title = title
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.headline)
            Spacer()
            if let onDismiss = onDismiss {
                DismissButton(action: onDismiss)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Layout.Elements.headerSmallHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
#endif
