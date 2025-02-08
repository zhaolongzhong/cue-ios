import SwiftUI
import GoogleSignIn

#if os(macOS)
import AppKit
#endif

struct ConnectedAppsView: View {
    @State private var gmailGranted = false
    @State private var inboxMessages: [String] = []
    private let gmailReadScope = "https://www.googleapis.com/auth/gmail.readonly"
    private let gmailSendScope = "https://www.googleapis.com/auth/gmail.send"
    private let gmailModifyScope = "https://www.googleapis.com/auth/gmail.modify"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gmail Access")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(gmailGranted ? "Granted" : "Not Granted")
                            .foregroundColor(gmailGranted ? .green : .red)
                    }
                    if !gmailGranted {
                        Button("Grant Gmail Access") {
                            requestGmailAccess()
                        }
                    } else {
                        Button("Fetch Inbox Messages") {
                            fetchInboxMessages()
                        }
                    }
                }

                Section(header: Text("Inbox Messages")) {
                    ForEach(inboxMessages, id: \.self) { messageID in
                        NavigationLink(destination: EmailPreviewView(messageID: messageID)) {
                            Text(messageID)
                        }
                    }
                }
            }
            .navigationTitle("Google Permissions")
            .onAppear(perform: checkGmailAccess)
        }
    }

    private func checkGmailAccess() {
        if let currentUser = GIDSignIn.sharedInstance.currentUser,
           let scopes = currentUser.grantedScopes,
           scopes.contains(gmailReadScope) &&
           scopes.contains(gmailSendScope) &&
           scopes.contains(gmailModifyScope) {
            gmailGranted = true
        } else {
            gmailGranted = false
        }
    }

    #if os(iOS)
    private func requestGmailAccess() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            AppLog.log.error("Could not get rootViewController on iOS")
            return
        }
        GIDSignIn.sharedInstance.currentUser?.addScopes([gmailReadScope, gmailSendScope, gmailModifyScope],
                                                          presenting: rootViewController) { _, error in
            if let error = error {
                AppLog.log.error("Error requesting Gmail scope: \(error.localizedDescription)")
                return
            }
            checkGmailAccess()
        }
    }
    #elseif os(macOS)
    private func requestGmailAccess() {
        guard let window = NSApplication.shared.windows.first else {
            AppLog.log.error("Could not get window on macOS")
            return
        }
        // Pass the window instead of the contentViewController
        GIDSignIn.sharedInstance.currentUser?.addScopes([gmailReadScope, gmailSendScope, gmailModifyScope],
                                                          presenting: window) { _, error in
            if let error = error {
                AppLog.log.error("Error requesting Gmail scope: \(error.localizedDescription)")
                return
            }
            checkGmailAccess()
        }
    }
    #endif

    private func fetchInboxMessages() {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser,
              let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?labelIds=INBOX")
        else {
            AppLog.log.error("No user or invalid URL")
            return
        }
        let accessToken = currentUser.accessToken.tokenString

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                AppLog.log.error("Error fetching messages: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data
            else {
                AppLog.log.error("Invalid response or no data")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let messages = json["messages"] as? [[String: Any]] {
                    // Extract message IDs
                    let ids = messages.compactMap { $0["id"] as? String }
                    DispatchQueue.main.async {
                        self.inboxMessages = ids
                    }
                } else {
                    AppLog.log.debug("No messages found")
                }
            } catch {
                AppLog.log.error("Error parsing JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
}
