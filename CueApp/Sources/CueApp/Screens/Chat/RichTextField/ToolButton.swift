//
//  ToolButton.swift
//  CueApp
//

import SwiftUI

struct ToolButton: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        HoverButton {
            Button(action: action) {
                HStack(spacing: 2) {
                    Image(systemName: "hammer")
                        .font(.system(size: 12))
                    Text("\(count)")
                }
            }
            .buttonStyle(.plain)
        }
    }
}
