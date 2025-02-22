import SwiftUI

#if os(macOS)
struct MacHeader: View {
    let title: String
    let onDismiss: () -> Void
    var showDismiss: Bool = true

    var body: some View {
        HStack {
            Spacer()
            Text(title)
                .font(.headline)
            Spacer()
            if showDismiss {
                DismissButton(action: onDismiss)
            }
        }
        .frame(maxWidth: .infinity, idealHeight: Layout.Elements.headerHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
#endif
