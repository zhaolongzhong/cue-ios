//
//  CollapsibleSettingsSection.swift
//  CueApp
//

import SwiftUI

struct CollapsibleSettingsSection<Content: View, Header: View>: View {
    let title: String
    let content: Content
    let headerView: Header
    @State private var isExpanded: Bool = false

    init(title: String, isExpandedByDefault: Bool = false,
         @ViewBuilder headerView: @escaping () -> Header,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self.headerView = headerView()
        self._isExpanded = State(initialValue: isExpandedByDefault)
    }

    init(title: String, isExpandedByDefault: Bool = false,
         @ViewBuilder content: () -> Content) where Header == DefaultCollapseSectionHeader {
        self.title = title
        self.content = content()
        self.headerView = DefaultCollapseSectionHeader(title: title)
        self._isExpanded = State(initialValue: isExpandedByDefault)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    headerView
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Divider()

                content
                    .padding(.vertical, 8)
            }
        }
//        .background(
//            RoundedRectangle(cornerRadius: 8)
//                .fill(AppTheme.Colors.controlButtonBackground)
//        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

struct DefaultCollapseSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}
