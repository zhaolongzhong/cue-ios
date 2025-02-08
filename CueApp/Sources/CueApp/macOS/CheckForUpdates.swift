import SwiftUI

#if os(macOS)
import Sparkle

public class DynamicFeedUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var dynamicFeedURL: String

    public init(initialURL: String) {
        self.dynamicFeedURL = initialURL
        super.init()
    }

    public func feedURLString(for updater: SPUUpdater) -> String? {
        return dynamicFeedURL
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

public struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    public init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    public var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}
#endif
