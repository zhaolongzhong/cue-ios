//
//  MCPServersList.swift
//  CueApp
//

import SwiftUI
import CueMCP
import CueOpenAI

struct MCPServersList: View {
    @ObservedObject var viewModel: MCPServersViewModel
    @Environment(\.openURL) private var openURL
    @State var activeSheet: SheetType?
    private let mcpServersRepository = URL(string: "https://modelcontextprotocol.io/examples")!

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
        .sheet(item: $activeSheet) { _ in
            sheetContent
                .sheetWidth(.large)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 8) {
                Text("MCP Servers")
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        #if os(macOS)
                        NSWorkspace.shared.open(mcpServersRepository)
                        #else
                        UIApplication.shared.open(mcpServersRepository)
                        #endif
                    } label: {
                        Label("Browse", systemImage: "globe")
                            .labelStyle(.iconOnly)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Browse more MCP servers")
                    .withIconHover()

                    Button {
                        activeSheet = .addServer
                    } label: {
                        Label("Add Server", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Add a new MCP server")
                    .withIconHover()
                }
            }
        }
    }

    private func serversListView(config: MCPServersConfig) -> some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(config.mcpServers.sorted(by: { $0.key < $1.key }), id: \.key) { serverName, server in
                ServerRow(
                    serverName: serverName,
                    server: server,
                    onShowTools: {
                        showToolsView(serverName)
                    },
                    onEdit: {
                        activeSheet = .editServer(serverName: serverName, server: server)
                    },
                    onDelete: {
                        viewModel.deleteServer(named: serverName)
                    }
                )
                .onTapGesture {
                    showToolsView(serverName)
                }
            }
        }
    }

    private func showToolsView(_ serverName: String) {
        #if os(macOS)
        let tools = viewModel.getMcpToolsBy(serverName: serverName)
        activeSheet = .tools(serverName: serverName, tools: tools)
        #endif
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
                activeSheet = .addServer
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
