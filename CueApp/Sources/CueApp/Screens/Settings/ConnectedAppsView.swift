import SwiftUI
import GoogleSignIn

#if os(macOS)
import AppKit
#endif

struct ConnectedAppsView: View {
    @State private var gmailGranted = false
    @State private var inboxMessages: [String] = []
    @State private var isLoading = false
    @State private var showingRemoveAlert = false

    private let gmailReadScope = "https://www.googleapis.com/auth/gmail.readonly"
    private let gmailSendScope = "https://www.googleapis.com/auth/gmail.send"
    private let gmailModifyScope = "https://www.googleapis.com/auth/gmail.modify"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                googleSection
            }
            .padding()
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 300)
        #endif
        .navigationTitle("Connected Apps")
        .onAppear(perform: checkGmailAccess)
    }

    private var googleSection: some View {
        GroupBox(label: Text("Google Account").bold()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(
                        title: { Text("Gmail Access") },
                        icon: { Image(systemName: "envelope.fill") }
                    )
                    Spacer()
                    HStack(spacing: 8) {
                        statusView
                        if gmailGranted {
                            Button(action: { showingRemoveAlert = true }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .imageScale(.medium)
                            }
                            .buttonStyle(.plain)
                            .help("Remove Gmail Access")
                        }
                    }
                }

                if !gmailGranted {
                    Button(action: requestGmailAccess) {
                        Label(
                            title: { Text("Grant Gmail Access") },
                            icon: { Image(systemName: "lock.open.fill") }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .alert("Remove Gmail Access", isPresented: $showingRemoveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeGmailAccess()
            }
        } message: {
            Text("Are you sure you want to remove Gmail access? You'll need to grant access again to use Gmail features.")
        }
    }

    private var statusView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(gmailGranted ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(gmailGranted ? "Connected" : "Not Connected")
                .foregroundColor(gmailGranted ? .green : .red)
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

    private func removeGmailAccess() {
        isLoading = true
        GIDSignIn.sharedInstance.signOut()
        isLoading = false
        checkGmailAccess()
    }

    #if os(iOS)
    private func requestGmailAccess() {
        // Get the current window scene and root view controller more reliably
        guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootViewController = windowScene.keyWindow?.rootViewController else {
            AppLog.log.error("Could not get rootViewController on iOS")
            return
        }
        
        isLoading = true

        // Check if user is already signed in
        if GIDSignIn.sharedInstance.currentUser == nil {
            // If no user is signed in, start with sign in
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
                if let error = error {
                    isLoading = false
                    AppLog.log.error("Error signing in: \(error.localizedDescription)")
                    return
                }
                
                // After successful sign in, request additional scopes
                signInResult?.user.addScopes(
                    [gmailReadScope, gmailSendScope, gmailModifyScope],
                    presenting: rootViewController
                ) { _, scopeError in
                    isLoading = false
                    if let scopeError = scopeError {
                        AppLog.log.error("Error requesting Gmail scope: \(scopeError.localizedDescription)")
                        return
                    }
                    checkGmailAccess()
                }
            }
        } else {
            // User is already signed in, just request additional scopes
            GIDSignIn.sharedInstance.currentUser?.addScopes(
                [gmailReadScope, gmailSendScope, gmailModifyScope],
                presenting: rootViewController
            ) { _, error in
                isLoading = false
                if let error = error {
                    AppLog.log.error("Error requesting Gmail scope: \(error.localizedDescription)")
                    return
                }
                checkGmailAccess()
            }
        }
    }
    #elseif os(macOS)
    private func requestGmailAccess() {
        guard let window = NSApplication.shared.windows.first else {
            AppLog.log.error("Could not get window on macOS")
            return
        }
        
        isLoading = true

        // If no user is signed in, start with sign in
        if GIDSignIn.sharedInstance.currentUser == nil {
            GIDSignIn.sharedInstance.signIn(withPresenting: window) { signInResult, error in
                if let error = error {
                    isLoading = false
                    AppLog.log.error("Error signing in: \(error.localizedDescription)")
                    return
                }

                // After successful sign in, request additional scopes
                signInResult?.user.addScopes(
                    [gmailReadScope, gmailSendScope, gmailModifyScope],
                    presenting: window
                ) { _, scopeError in
                    isLoading = false
                    if let scopeError = scopeError {
                        AppLog.log.error("Error requesting Gmail scope: \(scopeError.localizedDescription)")
                        return
                    }
                    checkGmailAccess()
                }
            }
        } else {
            // User is already signed in, just request additional scopes
            GIDSignIn.sharedInstance.currentUser?.addScopes(
                [gmailReadScope, gmailSendScope, gmailModifyScope],
                presenting: window
            ) { _, error in
                isLoading = false
                if let error = error {
                    AppLog.log.error("Error requesting Gmail scope: \(error.localizedDescription)")
                    return
                }
                checkGmailAccess()
            }
        }
    }
    #endif
}
