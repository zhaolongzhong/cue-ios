import SwiftUI
import Dependencies

struct FeatureFlagsView: View {
    @Dependency(\.featureFlagsViewModel) private var featureFlags

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable 3rd Party Provider", isOn: Binding(
                    get: { featureFlags.enableThirdPartyProvider },
                    set: { featureFlags.enableThirdPartyProvider = $0 }
                ))
            }
            .padding()
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 300)
        #endif
        .navigationTitle("Feature Flags")
    }
}
