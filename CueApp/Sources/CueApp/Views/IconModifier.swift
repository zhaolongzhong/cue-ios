//
//  IconModifier.swift
//  CueApp
//

import SwiftUI

struct IconModifier: ViewModifier {
    let size: CGFloat
    let frameSize: CGFloat
    let foregroundColor: Color

    init(fontSize: CGFloat = 18, frameSize: CGFloat = 24, foregroundColor: Color = .secondary) {
        self.size = fontSize
        self.frameSize = frameSize
        self.foregroundColor = foregroundColor
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
            .foregroundColor(foregroundColor)
            .frame(width: frameSize, height: frameSize)
            .contentShape(Rectangle())
    }
}

extension Image {
    @MainActor func asIcon(fontSize: CGFloat = 18, frameSize: CGFloat = 24, foregroundColor: Color = .primary) -> some View {
        self.modifier(IconModifier(fontSize: fontSize, frameSize: frameSize, foregroundColor: foregroundColor))
    }
}
