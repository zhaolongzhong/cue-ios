//
//  CenteredScrollView.swift
//  CueApp
//
import SwiftUI

struct CenteredScrollView<Content: View>: View {
    var maxWidth: CGFloat = 600
    var content: () -> Content

    init(maxWidth: CGFloat = 600, @ViewBuilder content: @escaping () -> Content) {
        self.maxWidth = maxWidth
        self.content = content
    }

    var body: some View {
        ScrollView {
            HStack {
                Spacer()
                content()
                    .frame(maxWidth: maxWidth)
                Spacer()
            }
        }
    }
}
