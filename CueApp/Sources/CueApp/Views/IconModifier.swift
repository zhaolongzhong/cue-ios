//
//  IconModifier.swift
//  CueApp
//

import SwiftUI

struct IconModifier: ViewModifier {
    let size: CGFloat
    let frameSize: CGFloat

    init(fontSize: CGFloat = 16, frameSize: CGFloat = 24) {
        self.size = fontSize
        self.frameSize = frameSize
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
            .frame(width: frameSize, height: frameSize)
            .contentShape(Rectangle())
    }
}

extension Image {
    @MainActor func asIcon(fontSize: CGFloat = 16, frameSize: CGFloat = 24) -> some View {
        self.modifier(IconModifier(fontSize: fontSize, frameSize: frameSize))
    }
}
