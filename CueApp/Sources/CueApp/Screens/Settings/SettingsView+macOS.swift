import Foundation
import SwiftUI
import Dependencies

struct SettingsListMacOS: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Dependency(\.featureFlagsViewModel) private var featureFlags
    @ObservedObject var viewModel: SettingsViewModel
    @AppStorage("colorScheme") private var colorScheme: ColorSchemeOption = .system
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled: Bool = true
    @ObservedObject var router: AppDestinationRouter
    let dismiss: DismissAction

    var body: some View {
        CenteredScrollView {
            contentView
                .padding()
        }
        .onAppear {
            updateAppearance()
        }
        .onChange(of: colorScheme) { _, _ in
            updateAppearance()
        }
    }

    var contentView: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            Section {
                GroupBox {
                    if let user = viewModel.currentUser {
                        UserInfoView(email: user.email)
                    }
                }
            } header: {
                SettingsHeader(title: "Account")
            }

            Section {
                GroupBox {
                    if featureFlags.enableProviders {
                        SettingsRow(systemIcon: "key.viewfinder", title: "Providers", showChevron: true, showDivider: true) {
                            router.navigate(to: AppDestination.providers)
                        }
                    }
                    if featureFlags.enableAssistants {
                        SettingsRow(systemIcon: "key", title: "API Keys", showChevron: true, showDivider: true) {
                            router.navigate(to: AppDestination.assistantAPIKeys)
                        }
                    }
                    SettingsRow(
                        systemIcon: "app.connected.to.app.below.fill",
                        title: "Connected Apps",
                        showChevron: true
                    ) {
                        router.navigate(to: AppDestination.connectedApps)
                    }
                }
            } header: {
                SettingsHeader(title: "Services")
            }

            Section {
                GroupBox {
                    SettingsRow(
                        systemIcon: "hammer",
                        title: "MCP Servers",
                        value: "",
                        showChevron: true,
                        showDivider: true
                    ) {
                        router.navigate(to: AppDestination.developer)
                    }
                    SettingsRow(
                        systemIcon: "flag",
                        title: "Feature Flags",
                        value: "",
                        showChevron: true
                    ) {
                        router.navigate(to: AppDestination.featureFlags)
                    }
                }
            } header: {
                SettingsHeader(title: "Developer")
            }

            Section {
                GroupBox {
                    SettingsRow(
                        systemIcon: "sun.max",
                        title: "Color Scheme",
                        value: "",
                        showChevron: false,
                        trailing: AnyView(
                            HStack {
                                Spacer()
                                Picker("", selection: $colorScheme) {
                                    ForEach(ColorSchemeOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.automatic)
                                .font(.system(size: 12))
                                .fixedSize()
                                .frame(height: 30)
                                .labelsHidden()
                            }
                        )
                    )
                    #if os(macOS)
                    if let appcastUrl = viewModel.appConfig?.appcastUrl {
                        SettingsRow(
                            systemIcon: "arrow.triangle.2.circlepath",
                            title: "Check for Updates",
                            showDivider: true
                        ) {
                            coordinator.checkForUpdates(withAppcastUrl: appcastUrl)
                        }
                    }
                    #endif

                    SettingsRow(
                        systemIcon: "info.circle",
                        title: "Version",
                        value: "\(viewModel.getVersionInfo())"
                    )
                }
            } header: {
                SettingsHeader(title: "App")
            }

            Section {
                GroupBox {
                    LogoutSection {
                        Task {
                            await viewModel.logout()
                            dismiss()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 600)
    }
}

extension SettingsListMacOS {
    private func updateAppearance() {
        #if os(macOS)
        let newAppearance: NSAppearance? = {
            if let appearanceName = colorScheme.toNSAppearanceName() {
                return NSAppearance(named: appearanceName)
            }
            return nil
        }()

        NSApplication.shared.appearance = newAppearance

        DispatchQueue.main.async {
            NSApplication.shared.windows.forEach { window in
                window.appearance = newAppearance
                window.contentView?.appearance = newAppearance
                window.contentView?.setNeedsDisplay(window.contentView?.bounds ?? .zero)
                window.contentView?.layoutSubtreeIfNeeded()
                window.invalidateShadow()
                window.display() // Force a redraw
            }
        }
        #endif
    }

}
extension ColorSchemeOption {
    #if os(macOS)
    func toNSAppearanceName() -> NSAppearance.Name? {
        switch self {
        case .system:
            return nil
        case .light:
            return .aqua
        case .dark:
            return .darkAqua
        }
    }
    #endif
}
