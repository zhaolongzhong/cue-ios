import SwiftUI

extension View {
    @ViewBuilder
    func resizableSheet() -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            self.presentationSizing(.fitted)
        } else {
            self
        }
        #endif
    }

    @ViewBuilder
    func defaultWindowSize() -> some View {
        self
            #if os(macOS)
            .frame(minWidth: 460, minHeight: 320)
            .frame(idealWidth: 800, idealHeight: 600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .resizableSheet()
            #endif
    }
}
