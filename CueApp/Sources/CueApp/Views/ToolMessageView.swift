import SwiftUI

struct ToolMessageView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var expansionState: ExpansionState = .collapsed
    @State private var isHovering = false
    let message: CueChatMessage

    enum ExpansionState {
        case collapsed
        case halfExpanded
        case fullyExpanded
    }

    var isExpanded: Bool {
        expansionState == .halfExpanded || expansionState == .fullyExpanded
    }

    var assistantMessage: String? {
        if case .string(let text)  = message.content {
            return text
        }
        return nil
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
            return message.toolArgs ?? ""
        } else if message.isToolMessage {
            return message.toolResultContent
        }
        return ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            assistantMessageView
            viewToolDetailButton
            if expansionState != .collapsed {
                ZStack {
                    ScrollView {
                        CodeBlockView(language: "json", code: content, isHeaderVisible: false, isBorderVisible: false)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isHovering {
                        controlButtons
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .frame(maxHeight: expansionState == .fullyExpanded ? .infinity : 150)
                .background(Color.clear)
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
        .padding(.vertical, 4)
    }

    private var assistantMessageView: some View {
        Group {
            if message.isTool, let text = assistantMessage?.trimmingCharacters(in: .whitespacesAndNewlines) {
                StyledTextView(content: text)
            }
        }
    }

    private var viewToolDetailButton: some View {
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
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)

                    }
                    .padding(8)
                    .frame(maxWidth: 250)
                    .contentShape(Rectangle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(isExpanded ? 0 : 0.5), lineWidth: 0.5)
                    )
                }
            )
            .buttonStyle(.plain)
            Spacer()
        }
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
                        #if os(macOS)
                        .background(Color(nsColor: .windowBackgroundColor))
                        #endif
                        #if os(iOS)
                        .background(Color(uiColor: .systemGray5))
                        #endif
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            )
            .buttonStyle(.plain)

            CopyButton(content: content, isVisible: true)
                .padding(4)
                #if os(macOS)
                .background(Color(nsColor: .windowBackgroundColor))
                #endif
                #if os(iOS)
                .background(Color(uiColor: .systemGray5))
                #endif
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.leading, 2)
        }
        .padding(8)
    }
}
