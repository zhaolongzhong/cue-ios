//
//  MessageVisibilityTracker.swift
//  CueApp
//

import SwiftUI

struct ViewVisibility: Equatable {
    let index: Double
    let rect: CGRect
}

struct ViewVisibilityKey: PreferenceKey {
    static let defaultValue: [ViewVisibility] = []

    static func reduce(value: inout [ViewVisibility], nextValue: () -> [ViewVisibility]) {
        value.append(contentsOf: nextValue())
    }
}

struct MessageVisibilityTracker: View {
    let index: Int

    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ViewVisibilityKey.self,
                value: [ViewVisibility(index: Double(index), rect: geo.frame(in: .global))]
            )
        }
    }
}
