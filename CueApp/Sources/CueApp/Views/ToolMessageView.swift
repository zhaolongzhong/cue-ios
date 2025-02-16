import SwiftUI

struct ToolMessageView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var expansionState: ExpansionState = .collapsed
    @State private var isHovering = false
    var message: CueChatMessage

    enum ExpansionState {
        case collapsed
        case halfExpanded
        case fullyExpanded
    }

    var isCollapsed: Bool {
        expansionState == .collapsed
    }

    var headerText: String {
        if message.isTool {
            return "View tool use details\(message.toolName.map { ": \($0.capitalized)" } ?? "")"
        } else if message.isToolMessage {
            return "View tool result"
        }
        return ""
    }

    var content: String {
        if message.isTool {
            let jsonString = message.toolArgs?
                .replacingOccurrences(of: "[", with: "{")
                .replacingOccurrences(of: "]", with: "}") ?? ""
            return jsonString
        } else if message.isToolMessage {
            return message.toolResultContent
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            if expansionState != .collapsed {
                ZStack {
                    ScrollView {
                        CodeBlockView(language: "json", code: content, hideHeader: true)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isHovering {
                        controlButtons
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .frame(maxHeight: expansionState == .fullyExpanded ? .infinity : 150)
                .background(Color.secondary.opacity(0.1))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                )
                #if os(macOS)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isHovering = hovering
                    }
                }
                #endif
            }
        }
        .padding(.bottom, message.isToolMessage ? 8 : 0)
    }

    private var headerView: some View {
        HStack {
            Button(
                action: {
                    withAnimation(.easeInOut) {
                        expansionState = expansionState == .collapsed ? .halfExpanded : .collapsed
                    }
                },
                label: {
                    HStack {
                        Text(headerText)
                            .font(.callout)
                            .foregroundColor(.primary.opacity(0.8))
                        Image(systemName: expansionState == .collapsed ? "chevron.right" : "chevron.down")
                            .foregroundColor(.secondary)
                            .font(.system(size: 10))
                    }
                }
            )
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var controlButtons: some View {
        HStack {
            Spacer()
            Button(
                action: {
                    withAnimation {
                        expansionState = expansionState == .halfExpanded ? .fullyExpanded : .halfExpanded
                    }
                },
                label: {
                    Image(systemName: expansionState == .fullyExpanded ? "arrow.up.right.and.arrow.down.left" : "arrow.down.left.and.arrow.up.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                        .padding(6)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            )
            .buttonStyle(.plain)

            CopyButton(content: content, isVisible: true)
                .padding(4)
                .background(Color.secondary.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.leading, 4)
        }
        .padding(8)
    }
}
