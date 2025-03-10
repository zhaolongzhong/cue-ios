//
//  ProviderSelectionMenu.swift
//  CueApp
//

import SwiftUI

struct ProviderSelectionMenu: View {
    @Binding var selectedProvider: Provider?
    let providersViewModel: ProvidersViewModel
    let featureFlags: FeatureFlagsViewModel
    @AppStorage("lastSelectedProviderId") private var lastSelectedProviderId: String = ""
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Current selected provider (or first available if none selected)
            if let currentProvider = selectedProvider ?? providersViewModel.enabledProviders.first(where: { $0.id == lastSelectedProviderId }) ?? providersViewModel.enabledProviders.first {
                HStack {
                    ProviderSidebarRow(provider: currentProvider) {
                        selectedProvider = currentProvider
                    }
                    .padding(.leading, 4)

                    Spacer()

                    Button {
                        isExpanded.toggle()
                    } label: {
                        Image(systemName: "chevron.down")
                            .asIcon()
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                            .withIconHover()
                    }
                    .buttonStyle(.plain)
                }
                // Show other providers when expanded
                if isExpanded {
                    ForEach(providersViewModel.enabledProviders, id: \.self) { provider in
                        // Only show providers that aren't currently selected
                        if provider != currentProvider {
                            switch provider {
                            case .openai where providersViewModel.isProviderEnabled(.openai) && featureFlags.enableOpenAI:
                                ProviderSidebarRow(provider: provider) {
                                    lastSelectedProviderId = provider.id
                                    selectedProvider = .openai
                                    isExpanded = false
                                }
                                .transition(.opacity)
                                .withHoverEffect()

                            case .anthropic where providersViewModel.isProviderEnabled(.anthropic) && featureFlags.enableAnthropic:
                                ProviderSidebarRow(provider: provider) {
                                    lastSelectedProviderId = provider.id
                                    selectedProvider = .anthropic
                                    isExpanded = false
                                }
                                .transition(.opacity)
                                .withHoverEffect()

                            case .gemini where providersViewModel.isProviderEnabled(.gemini) && featureFlags.enableGemini:
                                ProviderSidebarRow(provider: provider) {
                                    lastSelectedProviderId = provider.id
                                    selectedProvider = .gemini
                                    isExpanded = false
                                }
                                .transition(.opacity)
                                .withHoverEffect()

                            case .local where featureFlags.enableLocal:
                                ProviderSidebarRow(provider: provider) {
                                    lastSelectedProviderId = provider.id
                                    selectedProvider = .local
                                    isExpanded = false
                                }
                                .transition(.opacity)
                                .withHoverEffect()
                            case .cue where featureFlags.enableCue:
                                ProviderSidebarRow(provider: provider) {
                                    lastSelectedProviderId = provider.id
                                    selectedProvider = .cue
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
