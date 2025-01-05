import SwiftUI
import CueOpenAI

#if os(macOS)
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
                    createConfigButton
                }
                .padding()
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 300)
        .navigationTitle("Developer")
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
                Button("Edit Config") {
                    viewModel.openConfigFile()
                }
                .disabled(viewModel.configPath == nil)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var createConfigButton: some View {
        Group {
            if viewModel.configPath == nil {
                Button("Create Default Config", action: viewModel.createDefaultConfig)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
            }
        }
    }
}
#endif

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

private  enum SheetType: Identifiable {
    case tools(serverName: String, tools: [Tool])

    var id: String {
        switch self {
        case .tools(let serverName, _):
            return "tools-\(serverName)"
        }
    }
}
