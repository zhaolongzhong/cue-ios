//
//  StyledTextField.swift
//  CueApp
//

import SwiftUI

extension View {
    /// Applies a consistent styled appearance to TextEditor views
    /// - Parameter title: Optional navigation title to display
    /// - Returns: A view with the styling applied
    func styledTextField() -> some View {
        self
            .textFieldStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.all, 8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}
