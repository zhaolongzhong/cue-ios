import SwiftUI
import CueOpenAI

struct ToolsListView: View {
    @Environment(\.dismiss) var dismiss
    let tools: [Tool]
    let title: String
    
    // Group tools by category
    private var groupedTools: [String: [Tool]] {
        Dictionary(grouping: tools) { tool in
            // Extract category from tool name or use "General" as default
            let components = tool.name.components(separatedBy: ".")
            return components.count > 1 ? components[0] : "General"
        }
    }
    
    // Sorted categories
    private var sortedCategories: [String] {
        groupedTools.keys.sorted()
    }

    init(title: String? = nil, tools: [Tool]) {
        self.title = title ?? "Tools"
        self.tools = tools
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                toolsHeader
                
                ForEach(sortedCategories, id: \.self) { category in
                    toolCategorySection(category: category, tools: groupedTools[category] ?? [])
                }
            }
            .padding()
            #if os(macOS)
            .frame(maxWidth: 600)
            #endif
        }
        .navigationTitle(title)
        .defaultNavigationBar(title: title)
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 400)
        #endif
    }
    
    private var toolsHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading) {
                Text("Available Tools")
                    .font(.headline)
                
                Text("Tools that can be invoked by the AI assistant")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func toolCategorySection(category: String, tools: [Tool]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ToolSectionHeader(title: category)
            
            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(tools.enumerated()), id: \.element.name) { index, tool in
                        ToolRow(tool: tool)
                        
                        if index < tools.count - 1 {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(4)
            }
        }
    }
}

struct ToolSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.almostPrimary)
    }
}

struct ToolRow: View {
    var tool: Tool
    
    private var toolNameWithoutCategory: String {
        let components = tool.name.components(separatedBy: ".")
        return components.count > 1 ? components[1] : tool.name
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(toolNameWithoutCategory)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(tool.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                
                if !tool.parameters.isEmpty {
                    parametersView
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var parametersView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Parameters:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            ForEach(tool.parameters.prefix(3), id: \.name) { param in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 4, height: 4)
                    
                    Text(param.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if param.required {
                        Text("(required)")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }
            
            if tool.parameters.count > 3 {
                Text("+ \(tool.parameters.count - 3) more")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 10)
            }
        }
    }
}
