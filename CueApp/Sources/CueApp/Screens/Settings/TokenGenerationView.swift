import SwiftUI

struct TokenGenerationView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showsCopiedMessage = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isGeneratingToken {
                    ProgressView()
                } else if let token = viewModel.generatedToken {
                    Text(token)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)

                    Button("Copy Token") {
                        #if os(iOS)
                        UIPasteboard.general.string = token
                        #else
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(token, forType: .string)
                        #endif
                        showsCopiedMessage = true
                    }
                    .buttonStyle(.borderedProminent)
                    .overlay {
                        if showsCopiedMessage {
                            Text("Copied!")
                                .foregroundColor(.secondary)
                                .offset(x: 100)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        showsCopiedMessage = false
                                    }
                                }
                        }
                    }
                } else if let error = viewModel.tokenError {
                    Text(error)
                        .foregroundColor(.red)
                }

                Button(viewModel.generatedToken == nil ? "Generate Token" : "Regenerate Token") {
                    Task {
                        await viewModel.generateToken()
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGeneratingToken)
            }
            Spacer()
        }
    }
}
