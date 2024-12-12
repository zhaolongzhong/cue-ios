import SwiftUI

struct ToolsListView: View {
    @Environment(\.dismiss) var dismiss
    let tools: [MCPTool]

    var body: some View {
        #if os(macOS)
        VStack {
            content
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .padding(.trailing)
            }
            .padding(.bottom)
        }
        .frame(minWidth: 300, minHeight: 400)
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
        .padding(.top)
        #if os(macOS)
        .navigationTitle("Available Tools")
        #else
        .navigationTitle("Available Tools")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        #endif
    }
}
