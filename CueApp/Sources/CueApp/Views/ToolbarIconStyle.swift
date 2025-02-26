//
//  ToolbarIconStyle.swift
//  CueApp
//

import SwiftUI

struct ToolbarIconStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .font(.system(size: 16))
            .frame(width: 20, height: 20)
        #else
        content
            .font(.system(size: 22))
            .frame(width: 44, height: 44)
        #endif
    }
}
