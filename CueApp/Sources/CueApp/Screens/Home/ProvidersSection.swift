//
//  ProvidersSection.swift
//  CueApp
//

import SwiftUI

struct ProvidersSection: View {
    @Binding var selectedProvider: Provider?
    var providersViewModel: ProvidersViewModel
    var featureFlags: FeatureFlagsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Providers")

            ProviderSelectionMenu(
                selectedProvider: $selectedProvider,
                providersViewModel: providersViewModel,
                featureFlags: featureFlags
            )
        }
    }
}
