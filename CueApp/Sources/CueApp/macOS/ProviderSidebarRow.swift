//
//  Untitled.swift
//  CueApp
//

import SwiftUI

struct ProviderSidebarRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let provider: Provider
    let isSelected: Bool
    let action: () -> Void

    init(provider: Provider, isSelected: Bool = false, action: @escaping () -> Void) {
        self.provider = provider
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                ProviderAvatar(
                    iconName: provider.iconName,
                    isSystemImage: provider.isSystemIcon
                )

                Text(provider.displayName)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AppTheme.Colors.separator.opacity(0.5) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
