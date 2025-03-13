import SwiftUI
import CueOpenAI

struct ToolsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let tools: [Tool]
    private let title: String
    @State private var searchText: String = ""
    @State private var selectedTool: Tool?

    init(title: String? = nil, tools: [Tool]) {
        self.title = title ?? "Tools"
        self.tools = tools
    }

    private var filteredTools: [Tool] {
        if searchText.isEmpty {
            return tools
        } else {
            return tools.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(macOS)
            MacHeader(
                title: title,
                onDismiss: { dismiss() }
            )
            .padding(.bottom, 8)
            #endif

            if tools.isEmpty {
                emptyStateView
            } else {
                searchBar
                toolsList
                    .padding()
            }
        }
        .defaultNavigationBar(title: title)
        .background(colorScheme == .dark ? Color(.black).opacity(0.1) : Color(.gray).opacity(0.1))
        #if os(macOS)
        .sheetWidth(.medium)
        #endif
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search tools", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
        )
        .padding(.horizontal)
        .padding(.top)
    }

    private var toolsList: some View {
        List {
            ForEach(filteredTools, id: \.name) { tool in
                ToolRow(tool: tool)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTool = tool
                    }
            }
        }
        .listStyle(PlainListStyle())
        .background(Color.clear)
        .padding(.top, 4)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Tools Available")
                .font(.headline)

            Text("There are currently no tools configured for this model.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Components
struct ToolRow: View {
    var tool: Tool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tool.name)
                .font(.headline)

            Text(tool.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(5)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.black.opacity(0.1) : Color.white.opacity(0.5))
                .opacity(0.01)
        )
    }
}
