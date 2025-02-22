import SwiftUI
import CueOpenAI
import CueMCP

#if os(macOS)
import CueAnthropic

struct DeveloperView: View {
    @StateObject private var viewModel = DeveloperViewModel()
    @Environment(\.openURL) private var openURL
    @State private var activeSheet: SheetType?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    configSection
                    serversSection
                }
                .padding()
            }
            .padding()
        }
        .defaultNavigationBar(title: "Developer")
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .tools(let serverName, let tools):
                ToolsListView(
                    title: serverName,
                    tools: tools
                )
            }
        }
        .onAppear {
            Task {
                await viewModel.startServer()
            }
        }
    }

    private var configSection: some View {
        Section(header: Text("Model Context Protocol")
            .font(.headline)
            .padding(.bottom, 8)) {
        }
    }

    private var serversSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let config = viewModel.config {
                ForEach(config.mcpServers.sorted(by: { $0.key < $1.key }), id: \.key) { key, server in
                    ServerItemView(serverName: key, server: server) { serverName in
                        let tools = viewModel.getMcpToolsBy(serverName: serverName)
                        activeSheet = .tools(serverName: serverName, tools: tools)
                    }
                }
            }
        }
    }

    private func openDocumentsFolder() {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(documentsURL)
        }
    }
}

private struct ServerItemView: View {
    let serverName: String
    let server: MCPServerConfig
    let onTap: (String) -> Void

    var body: some View {
        Button {
            onTap(serverName)
        } label: {
            GroupBox(label: Text(serverName).bold()) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command: \(server.command)")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Args: \(server.args)")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

#endif

private enum SheetType: Identifiable {
    case tools(serverName: String, tools: [Tool])

    var id: String {
        switch self {
        case .tools(let serverName, _):
            return "tools-\(serverName)"
        }
    }
}
