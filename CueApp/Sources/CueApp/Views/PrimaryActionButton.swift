//
//  PrimaryActionButton.swift
//  CueApp
//

import SwiftUI

struct CancelButton: View {
    var label: String = "Cancel (esc)"
    var action: () -> Void

    var body: some View {
        Button(label) {
            action()
        }
        .keyboardShortcut(.escape, modifiers: [])
        .buttonStyle(.plain)
    }
}

struct PrimaryActionButton: View {
    var label: String
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(label) {
            action()
        }
        .keyboardShortcut(.return, modifiers: [])
        .disabled(isDisabled)
        .buttonStyle(.borderedProminent)
    }
}
