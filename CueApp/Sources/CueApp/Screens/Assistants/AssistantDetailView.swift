import SwiftUI

struct AssistantDetailView: View {
    let assistantsViewModel: AssistantsViewModel
    let assistant: AssistantStatus
    let status: ClientStatus?
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
                    await assistantsViewModel.updateAssistant(id: assistant.id, name: newName)
                }
            }
        } message: {
            Text("Enter a new name for this assistant")
        }
    }
}
