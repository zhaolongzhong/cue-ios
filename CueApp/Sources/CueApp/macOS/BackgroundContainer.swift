import SwiftUI

#if os(macOS)
import AppKit
#endif

struct BackgroundContainer: View {
    let backgroundOpacity: Double

    #if os(macOS)
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    init(
        backgroundOpacity: Double = 0.8,
        material: NSVisualEffectView.Material = .underWindowBackground,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.backgroundOpacity = backgroundOpacity
        self.material = material
        self.blendingMode = blendingMode
    }
    #else
    init(backgroundOpacity: Double = 0.8) {
        self.backgroundOpacity = backgroundOpacity
    }
    #endif

    var body: some View {
        #if os(macOS)
        ZStack {
            VisualEffectView(material: material, blendingMode: blendingMode)
                .ignoresSafeArea()
            AppTheme.Colors.background
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
        }
        #else
        AppTheme.Colors.background
            .opacity(backgroundOpacity)
            .ignoresSafeArea()
        #endif
    }
}
