import SwiftUI
import CueOpenAI

struct ToolsListView: View {
    @Environment(\.dismiss) var dismiss
    let tools: [Tool]

    var body: some View {
        #if os(macOS)
        NavigationStack {
            VStack {
                HStack {
                    Text("Available Tools")
                        .font(.headline)
                    Spacer()
                    DismissButton(action: { dismiss() })
                }
                .padding()
                content
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .frame(idealWidth: 800, idealHeight: 600)
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
        .navigationTitle("Available Tools")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                DismissButton(action: { dismiss() })
            }
        }
        #endif
    }
}
