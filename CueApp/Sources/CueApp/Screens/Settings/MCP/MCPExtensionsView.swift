import SwiftUI
import CueOpenAI
import CueAnthropic
import CueMCP

struct MCPExtensionsView: View {
    @StateObject var viewModel = MCPExtensionsViewModel()
    @Environment(\.openURL) private var openURL
    @State var activeSheet: SheetType?
    private let mcpServersRepository = URL(string: "https://github.com/modelcontextprotocol/servers")!

    var body: some View {
        CenteredScrollView {
            VStack(alignment: .leading, spacing: 32) {
                MCPConfigSection(
                    viewModel: viewModel,
                    onEditConfig: { viewModel.openConfigFile() },
                    onCreateConfig: { viewModel.createDefaultConfig() }
                )

                MCPServersSection(
                    viewModel: viewModel,
                    onAddServer: { activeSheet = .addServer },
                    onEditServer: { serverName, server in
                        activeSheet = .editServer(serverName: serverName, server: server)
                    },
                    onDeleteServer: { serverName in
                        viewModel.deleteServer(named: serverName)
                    },
                    onTapServer: { serverName in
                        #if os(macOS)
                        let tools = viewModel.getMcpToolsBy(serverName: serverName)
                        activeSheet = .tools(serverName: serverName, tools: tools)
                        #endif
                    },
                    onBrowseRepository: {
                        #if os(macOS)
                        NSWorkspace.shared.open(mcpServersRepository)
                        #else
                        UIApplication.shared.open(mcpServersRepository)
                        #endif
                    }
                )
            }
            .padding()
        }
        .defaultNavigationBar(title: "MCP Extensions")
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
        .sheet(item: $activeSheet) { _ in
            sheetContent
                .sheetWidth(.large)
        }
        .onAppear {
            Task {
                await viewModel.startServer()
            }
        }
    }

    private var sheetContent: some View {
        Group {
            switch activeSheet {
            case .tools(let serverName, let tools):
                ToolsListView(
                    title: serverName,
                    tools: tools
                )

            case .addServer:
                AddMCPServerView { newServer in
                    handleAddServer(newServer)
                }

            case .editServer(let serverName, let serverConfig):
                EditMCPServerView(
                    serverName: serverName,
                    server: MCPServerEditorModel.from(name: serverName, config: serverConfig),
                    onSave: { updatedServer in
                        handleUpdateServer(oldName: serverName, updatedServer: updatedServer)
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )

            case .none:
                EmptyView()
            }
        }
        .presentationCompactAdaptation(.popover)
    }

    private func handleAddServer(_ newServer: MCPServerEditorModel) {
        guard var config = viewModel.config, let configPath = viewModel.configPath else {
            return
        }

        config.mcpServers[newServer.name] = newServer.toServerConfig()
        ConfigManager.shared.saveConfig(config, to: configPath)
        viewModel.refreshConfig()
        activeSheet = nil
    }

    private func handleUpdateServer(oldName: String, updatedServer: MCPServerEditorModel) {
        guard var config = viewModel.config, let configPath = viewModel.configPath else {
            return
        }

        if oldName != updatedServer.name {
            config.mcpServers.removeValue(forKey: oldName)
        }

        config.mcpServers[updatedServer.name] = updatedServer.toServerConfig()
        ConfigManager.shared.saveConfig(config, to: configPath)
        viewModel.refreshConfig()
        activeSheet = nil
    }
}

struct MCPConfigSection: View {
    @ObservedObject var viewModel: MCPExtensionsViewModel
    var onEditConfig: () -> Void
    var onCreateConfig: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Text("MCP Extensions")
                        .font(.headline)
                }

                Spacer()

                if viewModel.configPath != nil {
                    Button {
                        onEditConfig()
                    } label: {
                        Label("Edit Config", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Edit configuration file")
                }
            }

            Text("The Model Context Protocol (MCP) standardizes how applications provide context to LLMs securely connect with local or remote resources using standard server setups.")
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let configPath = viewModel.configPath {
                ConfigActiveView(configPath: configPath)
            } else {
                NoConfigView(onCreateConfig: onCreateConfig)
            }
        }
    }
}

struct ConfigActiveView: View {
    let configPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configuration Active")
                        .font(.subheadline)
                        .fontWeight(.medium)

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
                Label("Create Configuration", systemImage: "plus.doc")
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

struct MCPServersSection: View {
    @ObservedObject var viewModel: MCPExtensionsViewModel
    var onAddServer: () -> Void
    var onEditServer: (String, MCPServerConfig) -> Void
    var onDeleteServer: (String) -> Void
    var onTapServer: (String) -> Void
    var onBrowseRepository: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView

            if let config = viewModel.config, !config.mcpServers.isEmpty {
                serversListView(config: config)
            } else {
                emptyServersView
            }
        }
        .animation(.easeInOut, value: viewModel.config?.mcpServers.isEmpty ?? true)
    }

    private var headerView: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                Text("Available MCP Servers")
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        onAddServer()
                    } label: {
                        Label("Add Server", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .help("Add a new MCP server")

                    Button {
                        onBrowseRepository()
                    } label: {
                        Label("Browse", systemImage: "globe")
                            .labelStyle(.iconOnly)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .help("Browse more MCP servers")
                }
            }
            Text("Each server contains a list of tools to use, click to check them out!")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private func serversListView(config: MCPServersConfig) -> some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(config.mcpServers.sorted(by: { $0.key < $1.key }), id: \.key) { key, server in
                ServerItemView(
                    serverName: key,
                    server: server,
                    onTap: { serverName in
                        onTapServer(serverName)
                    },
                    onEdit: {
                        onEditServer(key, server)
                    },
                    onDelete: {
                        onDeleteServer(key)
                    }
                )
            }
        }
    }

    private var emptyServersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.largeTitle)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            Text("No servers configured")
                .font(.callout)
                .foregroundColor(.secondary)

            Button {
                onAddServer()
            } label: {
                Label("Add Server", systemImage: "plus")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

enum SheetType: Identifiable {
    case tools(serverName: String, tools: [Tool])
    case addServer
    case editServer(serverName: String, server: MCPServerConfig)

    var id: String {
        switch self {
        case .tools(let serverName, _):
            return "tools-\(serverName)"
        case .addServer:
            return "add-server"
        case .editServer(let serverName, _):
            return "edit-server-\(serverName)"
        }
    }
}
