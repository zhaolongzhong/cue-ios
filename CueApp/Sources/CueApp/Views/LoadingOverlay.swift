import SwiftUI

public struct LoadingOverlay: View {
    let isVisible: Bool

    public var body: some View {
        if isVisible {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
