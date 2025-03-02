import SwiftUI

public struct ProviderDetailView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss

    private let provider: Provider
    @StateObject private var viewModel: ProviderDetailViewModel

    public init(provider: Provider) {
        self.provider = provider
        _viewModel = StateObject(wrappedValue: ProviderDetailViewModel(provider: provider))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                providerDetailsHeader
                Divider()
                providerSettingsSection
            }
            .padding()
            #if os(macOS)
            .frame(maxWidth: 600)
            #endif
        }
        .navigationTitle("\(provider.displayName) Settings")
        .defaultNavigationBar(title: "\(provider.displayName) Settings")
        .alert("API Key", isPresented: $viewModel.showingAPIKeyAlert) {
            TextField("Enter API Key", text: $viewModel.tempAPIKey)
                .autocorrectionDisabled()

            Button("Cancel", role: .cancel) {
                viewModel.cancelAPIKeyEditing()
            }

            Button("Save") {
                viewModel.saveAPIKey()
            }
        } message: {
            Text("Enter your API key for \(provider.displayName)")
        }
    }

    private var providerDetailsHeader: some View {
        HStack(spacing: 12) {
            provider.iconView
                .frame(width: 40, height: 40)

            VStack(alignment: .leading) {
                Text(provider.displayName)
                    .font(.headline)

                Text(provider.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var providerSettingsSection: some View {
        switch provider {
        case .local:
            LocalProviderSettingsSection(provider: provider, viewModel: viewModel)
        case .anthropic, .gemini, .openai, .cue:
            GenericProviderSettingsSection(provider: provider, viewModel: viewModel)
        }
    }
}

struct GenericProviderSettingsSection: View {
    let provider: Provider
    @ObservedObject var viewModel: ProviderDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // API Key Settings
            if provider.requiresAPIKey {
                Section {
                    GroupBox {
                        Button {
                            viewModel.promptForAPIKey()
                        } label: {
                            HStack {
                                Image(systemName: "key")
                                    .frame(width: 24)

                                Text("API Key")
                                    .foregroundColor(.primary)

                                Spacer()

                                Text(viewModel.hasAPIKey ? "••••••••" : "Not set")
                                    .foregroundColor(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                } header: {
                    ProviderDetailSectionHeader(title: "Authentication")
                }
                
                // Request Limit Settings
                Section {
                    RequestLimitView(
                        provider: provider,
                        requestLimit: $viewModel.requestLimit,
                        requestLimitWindow: $viewModel.requestLimitWindow
                    )
                } header: {
                    ProviderDetailSectionHeader(title: "Usage Limits")
                }
                .onAppear {
                    viewModel.refreshRequestCountData()
                }
            }
        }
    }
}

struct LocalProviderSettingsSection: View {
    let provider: Provider
    @ObservedObject var viewModel: ProviderDetailViewModel
    @State private var showingMaxMessageAlert = false
    @State private var maxMessagesInput = ""
    @State private var showingMaxTurnAlert = false
    @State private var maxTurnInput = ""
    @State private var showingBaseURLAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            basicSettingsView
            modelSettingsView
            serverSettingsView
            
            // Request Limit Settings
            Section {
                RequestLimitView(
                    provider: provider,
                    requestLimit: $viewModel.requestLimit,
                    requestLimitWindow: $viewModel.requestLimitWindow
                )
            } header: {
                ProviderDetailSectionHeader(title: "Usage Limits")
            }
            .onAppear {
                viewModel.refreshRequestCountData()
            }
            
            advancedSettingsView
        }
        .numberInputAlert(
            title: "Set Maximum Messages Per Turn",
            message: "Enter the maximum number of messages you want to use for each request.",
            isPresented: $showingMaxMessageAlert,
            inputValue: $maxMessagesInput,
            onSave: { newValue in
                viewModel.saveMaxMessages(newValue)
            }
        )
        .numberInputAlert(
            title: "Set Maximum Turns",
            message: "Enter the maximum number of turns you want to allow the model to run automatically.",
            isPresented: $showingMaxTurnAlert,
            inputValue: $maxTurnInput,
            onSave: { newValue in
                viewModel.saveMaxTurns(newValue)
            }
        )
        .alert("Server URL", isPresented: $viewModel.showingBaseURLAlert) {
            TextField("Server URL", text: $viewModel.tempBaseURL)
                .autocorrectionDisabled()

            Button("Reset to Default", role: .destructive) {
                viewModel.resetBaseURLToDefault()
                viewModel.showingBaseURLAlert = false
            }

            Button("Cancel", role: .cancel) {
                viewModel.cancelBaseURLEditing()
            }

            Button("Save") {
                viewModel.saveBaseURL()
            }
        } message: {
            Text("Enter the URL of your local model server.\nExample: \(Provider.localBaseURL)")
        }
    }

    private func settingRow(
        title: String,
        description: String? = nil,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.body)
                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(value)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var basicSettingsView: some View {
        Section {
            GroupBox {
                settingRow(
                    title: "Maximum Messages",
                    description: "The maximum number of messages for each request",
                    value: "\(viewModel.maxMessages)"
                ) {
                    maxMessagesInput = "\(viewModel.maxMessages)"
                    showingMaxMessageAlert = true
                }
                .padding(.all, 4)
                Divider()
                    .padding(.all, 4)
                settingRow(
                    title: "Maximum Turns",
                    description: "The maximum number of turns to allow the model to run automatically",
                    value: "\(viewModel.maxTurns)"
                ) {
                    maxTurnInput = "\(viewModel.maxTurns)"
                    showingMaxTurnAlert = true
                }
                .padding(.all, 4)

            }
        } header: {
            ProviderDetailSectionHeader(title: "Basic")
        }
    }

    private var modelSettingsView: some View {
        Section {
            GroupBox {
                StreamingToggle(
                    provider: .local,
                    isEnabled: $viewModel.isStreamingEnabled
                )
                .padding(.all, 4)
                Divider()
                    .padding(.all, 4)
                ToolsToggle(
                    provider: .local,
                    isEnabled: $viewModel.isToolEnabled
                )
                .padding(.all, 4)
            }
        } header: {
            ProviderDetailSectionHeader(title: "Model Settings")
        }
    }

    private var advancedSettingsView: some View {
        CollapsibleSettingsSection(
            title: "Advanced",
            headerView: {
                ProviderDetailSectionHeader(title: "Advanced")
            },
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reset Settings")
                                .foregroundColor(.primary)
                            Text("Restore default server URL and other settings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Reset") {
                            viewModel.resetBaseURLToDefault()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
            }
        )
    }

    private var serverSettingsView: some View {
        Section {
            GroupBox {
                settingRow(
                    title: "Server URL",
                    value: viewModel.baseURL
                ) {
                    viewModel.promptForBaseURL()
                }
                .padding(.all, 4)
            }
        } header: {
            ProviderDetailSectionHeader(title: "Server")
        }
    }
}

struct ProviderDetailSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.almostPrimary)
    }
}
