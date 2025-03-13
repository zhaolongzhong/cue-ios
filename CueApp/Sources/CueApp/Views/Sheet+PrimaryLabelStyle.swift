//
//  PrimaryLabelStyle.swift
//  CueApp
//

import SwiftUI

struct PrimaryLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.primary.opacity(0.9))
    }
}

struct SecondaryLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.callout)
            .foregroundColor(.secondary)
    }
}

extension View {
    func primaryLabel() -> some View {
        self.modifier(PrimaryLabelStyle())
    }

    func secondaryLabel() -> some View {
        self.modifier(SecondaryLabelStyle())
    }
}
