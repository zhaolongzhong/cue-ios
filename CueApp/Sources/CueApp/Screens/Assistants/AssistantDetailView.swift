import SwiftUI

struct AssistantDetailView: View {
    let assistantsViewModel: AssistantsViewModel
    @State var assistant: AssistantStatus
    let status: ClientStatus?
    let onUpdate: (AssistantStatus) -> Void
    @State private var showingNameEdit = false
    @State private var newName = ""

    var body: some View {
        List {
            Section("Details") {
                Button {
                    newName = assistant.name
                    showingNameEdit = true
                } label: {
                    LabeledContent("Name", value: assistant.name)
                }
            }
        }
        .navigationTitle("Assistant Details")
        .listStyle(.insetGrouped)
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
    }
}
