import SwiftUI
import CueOpenAI

struct ToolsListView: View {
    @Environment(\.dismiss) var dismiss
    let tools: [Tool]
    let title: String

    init(title: String? = nil, tools: [Tool]) {
        self.title = title ?? "Tools"
        self.tools = tools
    }

    var body: some View {
        VStack {
            #if os(macOS)
            MacHeader(
                title: "Tools",
                onDismiss: { dismiss() }
            )
            #endif

            content
        }
        .defaultNavigationBar(title: "Tools")
        #if os(macOS)
        .frame(width: 600, height: 400)
        #endif
    }

    private var content: some View {
        List(tools, id: \.name) { tool in
            ToolRow(tool: tool)
        }
    }
}

private struct ToolRow: View {
    var tool: Tool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tool.name)
                .font(.headline)
            Text(tool.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }
}
