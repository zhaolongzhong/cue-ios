//
//  MessageVisibilityTracker.swift
//  CueApp
//

import SwiftUI

struct ViewVisibility: Equatable {
    let index: Double
    let rect: CGRect

    static func == (lhs: ViewVisibility, rhs: ViewVisibility) -> Bool {
        // Only consider significant changes (>2 points) to reduce update frequency
        return lhs.index == rhs.index &&
               abs(lhs.rect.minY - rhs.rect.minY) < 2 &&
               abs(lhs.rect.maxY - rhs.rect.maxY) < 2
    }
}

struct ViewVisibilityKey: PreferenceKey {
    static let defaultValue: [ViewVisibility] = []

    static func reduce(value: inout [ViewVisibility], nextValue: () -> [ViewVisibility]) {
        // Merge strategy: Replace existing indices rather than appending
        let newValues = nextValue()
        for newValue in newValues {
            if let index = value.firstIndex(where: { $0.index == newValue.index }) {
                value[index] = newValue
            } else {
                value.append(newValue)
            }
        }
    }
}

struct MessageVisibilityTracker: View {
    let index: Int

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: ViewVisibilityKey.self,
                    value: [ViewVisibility(index: Double(index), rect: geo.frame(in: .global))]
                )
        }
    }
}
