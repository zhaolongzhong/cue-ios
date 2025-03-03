//
//  ScrollButton.swift
//  CueApp
//

import SwiftUI

struct ScrollButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(AppTheme.Colors.alternateInputBackground)
                .frame(width: platformButtonSize, height: platformButtonSize)
                .overlay(
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.Colors.primaryText)
                )
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .padding(16)
        .transition(.opacity)
    }

    private var platformButtonSize: CGFloat {
        #if os(iOS)
        36
        #else
        32
        #endif
    }
}
