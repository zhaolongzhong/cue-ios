import SwiftUI

struct TokenManagementView: View {
    @Binding var authToken: String
    @Environment(\.presentationMode) var presentationMode
    @State private var tempToken: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Token")) {
                    SecureField("Enter API Token", text: $tempToken)
                }

                if !authToken.isEmpty {
                    Section {
                        Button("Remove Token") {
                            authToken = ""
                            tempToken = ""
                            UserDefaults.standard.removeObject(forKey: "API_KEY")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Manage API Token")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                }
            }
        }
        .onAppear {
            tempToken = authToken
        }
    }

    private func saveAndDismiss() {
        if tempToken != authToken {
            authToken = tempToken
            UserDefaults.standard.set(authToken, forKey: "OpenAIToken")
        }
        presentationMode.wrappedValue.dismiss()
    }
}
