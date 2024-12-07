import SwiftUI

struct AssistantDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let assistantsViewModel: AssistantsViewModel
    @State var assistant: AssistantStatus
    @State private var showingNameEdit = false
    @State private var newName = ""
    @State private var selectedModel = ""
    @State private var showCopiedAlert = false
    let onUpdate: (AssistantStatus) -> Void

    let availableModels = [
        "claude-3-5-sonnet-20241022",
        "gpt-4o-mini",
        "gpt-4o",
        "o1-mini"
    ]

    var body: some View {
        List {
            Section("Details") {
                Button {
                    newName = assistant.name
                    showingNameEdit = true
                } label: {
                    LabeledContent("Name", value: assistant.name)
                }

                AssistantIDView(id: assistant.id)

                Picker("Model", selection: $selectedModel) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model)
                            .tag(model)
                    }
                }
                .onChange(of: selectedModel) { _, newValue in
                    Task {
                        guard let updatedAssistant = await assistantsViewModel.updateModel(id: assistant.id, model: newValue) else {
                            AppLog.log.error("Error when updating assistant model.")
                            return
                        }
                        self.assistant = updatedAssistant
                        onUpdate(updatedAssistant)
                    }
                }
            }
        }
        .navigationTitle("Assistant Details")
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.automatic)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        #endif
        .alert("Update Name", isPresented: $showingNameEdit) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { }
            Button("Update") {
                Task {
                    guard let updatedAssistant = await assistantsViewModel.updateAssistant(id: assistant.id, name: newName) else {
                        AppLog.log.error("Error when update assistant.")
                        return
                    }
                    self.assistant = updatedAssistant
                    onUpdate(updatedAssistant)
                }
            }
        } message: {
            Text("Enter a new name for this assistant")
        }
        .onAppear {
            selectedModel = assistant.assistant.metadata?.model ?? availableModels[0]
        }
    }
}

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
