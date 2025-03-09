//
//  ProviderSelectionMenu.swift
//  CueApp
//

import SwiftUI

struct ProviderSelectionMenu: View {
    let providers: [Provider]
    @Binding var selectedProvider: Provider?
    let providersViewModel: ProvidersViewModel
    let featureFlags: FeatureFlagsViewModel

    // State to track if the menu is expanded
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Current selected provider (or first available if none selected)
            if let currentProvider = selectedProvider ?? providers.first {
                HStack {
                    ProviderSidebarRow(
                        provider: currentProvider,
                        isSelected: false
                    ) {
                        selectedProvider = currentProvider
                    }
                    .padding(.leading, 4)

                    Spacer()

                    Button(action: {
                        isExpanded.toggle()
                    }) {
                        // Chevron icon that rotates based on expanded state
                        Image(systemName: "chevron.down")
                            .asIcon()
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                            .withIconHover()
                    }
                    .buttonStyle(.plain)
                }
                // Show other providers when expanded
                if isExpanded {
                    ForEach(providers, id: \.self) { provider in
                        // Only show providers that aren't currently selected
                        if provider != currentProvider {
                            switch provider {
                            case .openai where providersViewModel.isProviderEnabled(.openai) && featureFlags.enableOpenAI:
                                ProviderSidebarRow(provider: provider, isSelected: false) {
                                    selectedProvider = .openai
                                    isExpanded = false
                                }
                                .transition(.opacity)
                                .withHoverEffect()

                            case .anthropic where providersViewModel.isProviderEnabled(.anthropic) && featureFlags.enableAnthropic:
                                ProviderSidebarRow(provider: provider, isSelected: false) {
                                    selectedProvider = .anthropic
                                    isExpanded = false
                                }
                                .transition(.opacity)
                                .withHoverEffect()

                            case .gemini where providersViewModel.isProviderEnabled(.gemini) && featureFlags.enableGemini:
                                ProviderSidebarRow(provider: provider, isSelected: false) {
                                    selectedProvider = .gemini
                                    isExpanded = false
                                }
                                .transition(.opacity)
                                .withHoverEffect()

                            case .local where featureFlags.enableLocal:
                                ProviderSidebarRow(provider: provider, isSelected: false) {
                                    selectedProvider = .local
                                    isExpanded = false
                                }
                                .transition(.opacity)
                                .withHoverEffect()

                            default:
                                EmptyView()
                            }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
