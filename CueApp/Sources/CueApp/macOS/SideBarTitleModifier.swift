//
//  SideBarTitleModifier.swift
//  CueApp
//

import SwiftUI

// MARK: - SideBarTitleModifier
struct SideBarTitleModifier: ViewModifier {
    var alignment: HorizontalAlignment = .leading
    var fontStyle: Font = .subheadline
    var fontWeight: Font.Weight = .semibold
    var textColor: Color = .secondary

    func body(content: Content) -> some View {
        content
            .font(fontStyle)
            .fontWeight(fontWeight)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .foregroundColor(textColor)
    }
}

// MARK: - View Extension
extension View {
    func withSideBarTitle(
        alignment: HorizontalAlignment = .leading,
        fontStyle: Font = .subheadline,
        fontWeight: Font.Weight = .bold,
        textColor: Color = .secondary
    ) -> some View {
        modifier(
            SideBarTitleModifier(
                alignment: alignment,
                fontStyle: fontStyle,
                fontWeight: fontWeight,
                textColor: textColor
            )
        )
    }
}
