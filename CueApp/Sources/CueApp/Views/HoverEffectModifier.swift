//
//  HoverEffectModifier.swift
//  CueApp
//

import SwiftUI

struct HoverEffectModifier: ViewModifier {
    @State private var isHovering = false

    // Background appearance
    var backgroundColor: Color = Color.gray.opacity(0.2)
    var cornerRadius: CGFloat = 6

    // Padding options
    var padding: EdgeInsets?
    var horizontalPadding: CGFloat?
    var verticalPadding: CGFloat?

    // Fixed size options
    var fixedWidth: CGFloat?
    var fixedHeight: CGFloat?
    var minWidth: CGFloat?
    var minHeight: CGFloat?
    var alignment: Alignment = .center

    // Animation
    var animationDuration: Double = 0.15

    // Additional effects
    var scale: CGFloat?
    var shadowRadius: CGFloat?

    // Callback
    var onHoverChange: ((Bool) -> Void)?

    func body(content: Content) -> some View {
        let paddedContent = Group {
            if let customPadding = padding {
                content.padding(customPadding)
            } else if horizontalPadding != nil || verticalPadding != nil {
                content
                    .padding(.horizontal, horizontalPadding ?? 0)
                    .padding(.vertical, verticalPadding ?? 0)
            } else {
                content
            }
        }

        // Apply fixed size constraints if provided
        let sizedContent = Group {
            if fixedWidth != nil || fixedHeight != nil {
                paddedContent.frame(
                    width: fixedWidth,
                    height: fixedHeight,
                    alignment: alignment
                )
            } else if minWidth != nil || minHeight != nil {
                paddedContent.frame(
                    minWidth: minWidth,
                    minHeight: minHeight,
                    alignment: alignment
                )
            } else {
                paddedContent
            }
        }

        return sizedContent
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .opacity(isHovering ? 1 : 0)
            )
            .scaleEffect(isHovering && scale != nil ? scale! : 1.0)
            .shadow(radius: isHovering && shadowRadius != nil ? shadowRadius! : 0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: animationDuration)) {
                    isHovering = hovering
                    onHoverChange?(hovering)
                }
            }
            .contentShape(Rectangle())
    }
}

extension View {
    // Standard hover effect with fixed size options
    func withHoverEffect(
        backgroundColor: Color = Color.gray.opacity(0.1),
        cornerRadius: CGFloat = 8,
        horizontalPadding: CGFloat = 4,
        verticalPadding: CGFloat = 2,
        fixedWidth: CGFloat? = nil,
        fixedHeight: CGFloat? = nil,
        alignment: Alignment = .center,
        animationDuration: Double = 0.15,
        scale: CGFloat? = nil,
        shadowRadius: CGFloat? = nil,
        onHoverChange: ((Bool) -> Void)? = nil
    ) -> some View {
        #if os(macOS)
        // Apply the real hover effect only on macOS
        return modifier(
            HoverEffectModifier(
                backgroundColor: backgroundColor,
                cornerRadius: cornerRadius,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                fixedWidth: fixedWidth,
                fixedHeight: fixedHeight,
                alignment: alignment,
                animationDuration: animationDuration,
                scale: scale,
                shadowRadius: shadowRadius,
                onHoverChange: onHoverChange
            )
        )
        #else
        return self
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(
                width: fixedWidth,
                height: fixedHeight,
                alignment: alignment
            )
            .cornerRadius(cornerRadius)
        #endif
    }

    // Icon-specific hover effect with square dimensions
    func withIconHover(
        size: CGFloat = 24,
        backgroundColor: Color = AppTheme.Colors.textColor.opacity(0.1),
        cornerRadius: CGFloat = 6,
        padding: CGFloat = 6,
        animationDuration: Double = 0.15,
        scale: CGFloat? = nil,
        shadowRadius: CGFloat? = nil,
        onHoverChange: ((Bool) -> Void)? = nil
    ) -> some View {
        modifier(
            HoverEffectModifier(
                backgroundColor: backgroundColor,
                cornerRadius: cornerRadius,
                horizontalPadding: padding,
                verticalPadding: padding,
                fixedWidth: size,
                fixedHeight: size,
                alignment: .center,
                animationDuration: animationDuration,
                scale: scale,
                shadowRadius: shadowRadius,
                onHoverChange: onHoverChange
            )
        )
    }

    // Custom hover with all options
    func withCustomHover(
        backgroundColor: Color = Color.gray.opacity(0.1),
        cornerRadius: CGFloat = 6,
        padding: EdgeInsets? = nil,
        horizontalPadding: CGFloat? = nil,
        verticalPadding: CGFloat? = nil,
        fixedWidth: CGFloat? = nil,
        fixedHeight: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        alignment: Alignment = .center,
        animationDuration: Double = 0.15,
        scale: CGFloat? = nil,
        shadowRadius: CGFloat? = nil,
        onHoverChange: ((Bool) -> Void)? = nil
    ) -> some View {
        modifier(
            HoverEffectModifier(
                backgroundColor: backgroundColor,
                cornerRadius: cornerRadius,
                padding: padding,
                horizontalPadding: horizontalPadding,
                verticalPadding: verticalPadding,
                fixedWidth: fixedWidth,
                fixedHeight: fixedHeight,
                minWidth: minWidth,
                minHeight: minHeight,
                alignment: alignment,
                animationDuration: animationDuration,
                scale: scale,
                shadowRadius: shadowRadius,
                onHoverChange: onHoverChange
            )
        )
    }

    // Minimal hover without padding but with size options
    func withMinimalHover(
        backgroundColor: Color = Color.gray.opacity(0.1),
        cornerRadius: CGFloat = 6,
        fixedSize: CGFloat? = nil,
        minSize: CGFloat? = nil,
        animationDuration: Double = 0.15,
        scale: CGFloat? = nil,
        shadowRadius: CGFloat? = nil,
        onHoverChange: ((Bool) -> Void)? = nil
    ) -> some View {
        modifier(
            HoverEffectModifier(
                backgroundColor: backgroundColor,
                cornerRadius: cornerRadius,
                horizontalPadding: 0,
                verticalPadding: 0,
                fixedWidth: fixedSize,
                fixedHeight: fixedSize,
                minWidth: minSize,
                minHeight: minSize,
                animationDuration: animationDuration,
                scale: scale,
                shadowRadius: shadowRadius,
                onHoverChange: onHoverChange
            )
        )
    }
}
