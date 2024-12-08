import SwiftUI

struct AssistantIDView: View {
    let id: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopiedAlert = false

    private var shortId: String {
        let lastSix = String(id.suffix(6))
        return "asst_\(lastSix)"
    }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(id)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: .trailing) {
                    Button {
                        #if os(iOS)
                        UIPasteboard.general.string = id
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(id, forType: .string)
                        #endif
                        showCopiedAlert = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedAlert = false
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                    .buttonStyle(.plain)

                    if showCopiedAlert {
                        Text("Copied!")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .offset(x: -4)  // Adjusted to keep alert inside bounds
                            .transition(.opacity)
                            .animation(.easeInOut, value: showCopiedAlert)
                    }
                }
            }
        } label: {
            Text("ID")
        }
    }
}
