//
//  SheetWidthModifier.swift
//  CueApp
//

import SwiftUI

// MARK: - Sheet Width Modifier

/// A view modifier that sets a preferred width for sheets on macOS
/// while having no effect on other platforms
struct SheetWidthModifier: ViewModifier {
    let width: CGFloat
    let minHeight: CGFloat?

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .frame(maxWidth: width, minHeight: minHeight)
        #else
        content
        #endif
    }
}

// MARK: - View Extension

extension View {
    /// Sets a preferred width for the view when presented in a sheet on macOS.
    /// Has no effect on other platforms.
    /// - Parameter width: The preferred width for the sheet
    /// - Parameter minHeight: Optional minimum height for the sheet
    /// - Returns: A modified view with the specified dimensions applied on macOS
    func sheetWidth(_ width: CGFloat, minHeight: CGFloat? = nil) -> some View {
        modifier(SheetWidthModifier(width: width, minHeight: minHeight))
    }

    /// Sets a standard width for sheets on macOS based on predefined sizes.
    /// Has no effect on other platforms.
    /// - Parameter size: The predefined size to use
    /// - Parameter minHeight: Optional minimum height for the sheet
    /// - Returns: A modified view with the specified dimensions applied on macOS
    func sheetWidth(_ size: SheetSize, minHeight: CGFloat? = 400) -> some View {
        modifier(SheetWidthModifier(width: size.width, minHeight: minHeight))
    }

    /// Applies standard padding and sizing for sheet content
    /// - Parameter bottomPadding: The amount of bottom padding to apply
    /// - Returns: A modified view with appropriate padding
    func sheetContentPadding(bottomPadding: CGFloat = 20) -> some View {
        self.padding(.bottom, bottomPadding)
    }

    /// Configures a view as a standard sheet with appropriate dimensions and padding
    /// - Parameters:
    ///   - size: The predefined size to use
    ///   - minHeight: The minimum height for the sheet
    /// - Returns: A modified view ready to be used as a sheet
    func standardSheet(size: SheetSize = .medium, minHeight: CGFloat = 300) -> some View {
        self
            .sheetWidth(size, minHeight: minHeight)
            .sheetContentPadding()
    }
}

// MARK: - Sheet Size Enum

/// Predefined sheet sizes for convenience
enum SheetSize {
    case small
    case medium
    case large
    case custom(CGFloat)

    var width: CGFloat {
        switch self {
        case .small:
            return 400
        case .medium:
            return 600
        case .large:
            return 800
        case .custom(let width):
            return width
        }
    }
}
