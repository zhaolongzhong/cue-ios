//
//  SlidingSidebar.swift
//  CueApp
//

import SwiftUI

/// A reusable sliding sidebar that can be used across the app
struct SlidingSidebar<Content: View>: View {
    @Binding var isShowing: Bool
    let width: CGFloat
    let edge: Edge
    let content: Content
    let onDismiss: (() -> Void)?
    let showOverlay: Bool
    let overlayOpacity: Double
    let animationDuration: Double
    let sidebarOpacity: Double
    let blurIntensity: CGFloat

    init(
        isShowing: Binding<Bool>,
        width: CGFloat = 280,
        edge: Edge = .trailing,
        showOverlay: Bool = true,
        overlayOpacity: Double = 0.2,
        sidebarOpacity: Double = 0.7,
        blurIntensity: CGFloat = 5,
        animationDuration: Double = 0.3,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._isShowing = isShowing
        self.width = width
        self.edge = edge
        self.showOverlay = showOverlay
        self.overlayOpacity = overlayOpacity
        self.sidebarOpacity = sidebarOpacity
        self.blurIntensity = blurIntensity
        self.animationDuration = animationDuration
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: edge == .trailing ? .trailing : .leading) {
            // Semi-transparent overlay to capture taps outside the sidebar
            Group {
                if isShowing {
                    if showOverlay {
                        Color.black.opacity(overlayOpacity)
                    } else {
                        Color.clear
                    }
                }
            }
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.easeInOut(duration: animationDuration)) {
                    isShowing = false
                    onDismiss?()
                }
            }

            ZStack {
                #if os(macOS)
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                #else
                // Fallback for non-macOS platforms
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .blur(radius: 3)
                #endif

                // Vertical line on the left/right edge (depending on sidebar position)
                HStack(spacing: 0) {
                    if edge == .trailing {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 0.5)
                            .frame(maxHeight: .infinity)
                        Spacer()
                    } else {
                        Spacer()
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 1)
                            .frame(maxHeight: .infinity)
                            .padding(.vertical, 10)
                    }
                }

                // Content on top
                content
            }
            .frame(width: width)
            .clipShape(Rectangle())
            .offset(x: offsetValue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: edge == .trailing ? .trailing : .leading)
        .animation(.easeInOut(duration: animationDuration), value: isShowing)
    }

    private var offsetValue: CGFloat {
        switch edge {
        case .trailing:
            return isShowing ? 0 : width
        case .leading:
            return isShowing ? 0 : -width
        default:
            // Only supporting leading and trailing edges
            return 0
        }
    }
}

extension View {
    /// Adds a sliding sidebar to the current view
    /// - Parameters:
    ///   - isShowing: Binding to control sidebar visibility
    ///   - width: Width of the sidebar
    ///   - edge: Edge from which the sidebar appears (.leading or .trailing)
    ///   - showOverlay: Whether to show an overlay behind the sidebar
    ///   - overlayOpacity: Opacity of the overlay (0-1)
    ///   - sidebarOpacity: Opacity of the sidebar background (0-1)
    ///   - blurIntensity: Intensity of the blur effect
    ///   - animationDuration: Duration of the slide animation
    ///   - onDismiss: Optional closure to run when sidebar is dismissed
    ///   - content: The content view of the sidebar
    /// - Returns: A view with the sidebar attached
    func slidingSidebar<Content: View>(
        isShowing: Binding<Bool>,
        width: CGFloat = 280,
        edge: Edge = .trailing,
        showOverlay: Bool = false,
        overlayOpacity: Double = 0.2,
        sidebarOpacity: Double = 0.7,
        blurIntensity: CGFloat = 5,
        animationDuration: Double = 0.2,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ZStack {
            self // Original view
                .zIndex(0)

            SlidingSidebar(
                isShowing: isShowing,
                width: width,
                edge: edge,
                showOverlay: showOverlay,
                overlayOpacity: overlayOpacity,
                sidebarOpacity: sidebarOpacity,
                blurIntensity: blurIntensity,
                animationDuration: animationDuration,
                onDismiss: onDismiss,
                content: content
            )
            .zIndex(1) // Ensure sidebar is above the main content
        }
    }
}
