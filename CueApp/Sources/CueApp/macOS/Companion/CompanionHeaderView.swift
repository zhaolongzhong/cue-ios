import SwiftUI

public struct CompanionHeaderView: View {
    @Binding var isHovering: Bool
    let title: String?
    let forceShow: Bool
    let onDismiss: (() -> Void)?

    public init(title: String? = nil, isHovering: Binding<Bool>, forceShow: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.title = title
        self._isHovering = isHovering
        self.forceShow = forceShow
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            #if os(macOS)
            Group {
                if isHovering {
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                }
            }
            Rectangle().fill(Color.clear)
            #endif

            if forceShow || isHovering {
                if let title = title {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                HStack {
                    Spacer()
                    DismissButton(action: onDismiss)
                        .padding(.trailing, 4)
                }
            }
        }
        .contentShape(Rectangle())
        .frame(height: Layout.Elements.headerSmallHeight)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
