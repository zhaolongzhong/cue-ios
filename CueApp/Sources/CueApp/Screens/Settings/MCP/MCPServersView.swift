import SwiftUI
import CueOpenAI
import CueAnthropic
import CueMCP

struct MCPServersView: View {
    @StateObject private var viewModel: MCPServersViewModel

    init(viewModelFactory: @escaping () -> MCPServersViewModel) {
        _viewModel = StateObject(wrappedValue: viewModelFactory())
    }

    var body: some View {
        CenteredScrollView {
            VStack(alignment: .leading, spacing: 32) {
                MCPConfigSection(
                    viewModel: viewModel,
                    onEditConfig: { viewModel.openConfigFile() },
                    onCreateConfig: { viewModel.createDefaultConfig() }
                )

                MCPServersList(
                    viewModel: viewModel
                )
            }
            .padding()
        }
        .defaultNavigationBar(title: "MCP Servers")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Menu {
                    if viewModel.configPath != nil {
                        Button("MCP Config") {
                            viewModel.openConfigFile()
                        }
                    } else {
                        Button("Create MCP Config") {
                            viewModel.createDefaultConfig()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.primary)
                }
                .menuIndicator(.hidden)
            }
        }
        .onAppear {
            Task {
                await viewModel.startServer()
            }
        }
    }
}

struct MCPConfigSection: View {
    @ObservedObject var viewModel: MCPServersViewModel
    var onEditConfig: () -> Void
    var onCreateConfig: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overview")
                    .font(.headline)
            }

            Text("The Model Context Protocol (MCP) standardizes how applications provide context to LLMs securely connect with local or remote resources using standard server setups.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let configPath = viewModel.configPath {
                ConfigFileView(configPath: configPath, onEditConfig: onEditConfig)
            } else {
                NoConfigView(onCreateConfig: onCreateConfig)
            }
        }
    }
}

struct ConfigFileView: View {
    let configPath: String
    var onEditConfig: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Button {
                            onEditConfig()
                        } label: {
                            HStack {
                                Text("Edit Config")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Image(systemName: "pencil")

                            }
                        }
                        .buttonStyle(.plain)
                        .controlSize(.small)
                        .help("Edit configuration file")
                    }

                    HStack(spacing: 4) {
                        Text(configPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        CopyButton(
                            content: configPath,
                            isVisible: true
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
                .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct NoConfigView: View {
    var onCreateConfig: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text("No Configuration Found")
                .font(.callout)
                .fontWeight(.medium)

            Text("MCP requires a configuration file to communicate with language models.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Button {
                onCreateConfig()
            } label: {
                Label("Create", systemImage: "plus.doc")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}
