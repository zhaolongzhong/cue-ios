//
//  ConversationRow.swift
//  CueApp
//

import SwiftUI

struct ConversationRow: View {
    let conversation: ConversationModel
    let isSelected: Bool
    let isSelectMode: Bool
    let isSelected_MultiSelect: Bool
    @State private var isHovering = false

    var onSelect: () -> Void
    var onToggleSelection: () -> Void
    var onDelete: () -> Void
    var onRename: () -> Void

    var body: some View {
        HStack {
            // Checkbox in select mode
            if isSelectMode {
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected_MultiSelect ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected_MultiSelect ? .accentColor : .gray)
                        .font(.system(size: 16))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .withIconHover()
            }

            // Main content button - title
            Button(action: isSelectMode ? onToggleSelection : onSelect) {
                HStack {
                    Text(conversation.title)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Action buttons when not in select mode
            if !isSelectMode {
                HStack(spacing: 4) {
                    Menu {
                        Button(action: onRename) {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(action: onRename) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1 : 0)
                    .withIconHover()
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    isSelected && !isSelectMode ? AppTheme.Colors.separator.opacity(0.5) :
                    isSelected_MultiSelect && isSelectMode ? Color.accentColor.opacity(0.15) :
                    isHovering ? Color.gray.opacity(0.1) : Color.clear
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
