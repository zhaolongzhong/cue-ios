import SwiftUI

struct DefaultNavigationBarModifier: ViewModifier {
    let hideBackButton: Bool
    let showCustomBackButton: Bool
    let title: String?
    @Environment(\.dismiss) private var dismiss

    init(
        hideBackButton: Bool = true,
        showCustomBackButton: Bool = true,
        title: String? = nil
    ) {
        self.hideBackButton = hideBackButton
        self.showCustomBackButton = showCustomBackButton
        self.title = title
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(hideBackButton)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if showCustomBackButton {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                        }
                    }
                }

                if let title = title {
                    ToolbarItem(placement: .principal) {
                        Text(title)
                            .font(.headline)
                    }
                }
            }
        #else
        content
        #endif
    }
}

extension View {
    func defaultNavigationBar(
        hideBackButton: Bool = true,
        showCustomBackButton: Bool = true,
        title: String? = nil
    ) -> some View {
        modifier(DefaultNavigationBarModifier(
            hideBackButton: hideBackButton,
            showCustomBackButton: showCustomBackButton,
            title: title
        ))
    }
}