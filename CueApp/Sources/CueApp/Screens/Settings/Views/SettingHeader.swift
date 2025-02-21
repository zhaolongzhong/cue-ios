import SwiftUI

struct SettingsHeader: View {
    let title: String
    var body: some View {
        Text(title)
            #if os(macOS)
            .font(.callout)
            .padding(.leading, 8)
            #else
            .font(.footnote.bold())
            .padding(.leading, -8)
            #endif
    }
}
