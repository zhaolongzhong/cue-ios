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
        #if os(macOS)
        VStack {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                DismissButton(action: { dismiss() })
            }
            .padding()
            content
        }
        .frame(minHeight: 400, maxHeight: 600)
        .frame(width: 600)
        .resizableSheet()
        #else
        NavigationView {
            content
        }
        #endif
    }

    private var content: some View {
        List(tools, id: \.name) { tool in
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
        #if os(iOS)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                DismissButton(action: { dismiss() })
            }
        }
        #endif
    }
}
