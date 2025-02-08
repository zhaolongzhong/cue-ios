import SwiftUI
import GoogleSignIn

struct EmailPreviewView: View {
    let messageID: String
    @State private var previewText = "Loading preview…"

    var body: some View {
        ScrollView {
            Text(previewText)
                .padding()
        }
        .navigationTitle("Email Preview")
        .task {
            previewText = await fetchMessageDetails(messageID: messageID) ?? "Failed to load preview."
        }
    }

    func fetchMessageDetails(messageID: String) async -> String? {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser,
              let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(messageID)?format=full")
        else { return nil }

        let accessToken = currentUser.accessToken.tokenString
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let snippet = json["snippet"] as? String {
                return snippet
            }
            return "No preview available."
        } catch {
            print("Error fetching details: \(error)")
            return nil
        }
    }
}
