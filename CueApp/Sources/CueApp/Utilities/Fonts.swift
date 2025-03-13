//
//  Fonts.swift
//  CueApp
//
import SwiftUI

#if os(macOS)
extension NSFont {
    func with(traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return NSFont(descriptor: descriptor, size: 0) ?? self
    }
}
#endif
