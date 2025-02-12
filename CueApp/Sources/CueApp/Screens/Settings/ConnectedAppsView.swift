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
        gmailGranted = GmailAuthHelper.shared.checkGmailAccessScopes()
    }

    private func removeGmailAccess() {
        isLoading = true
        GmailAuthHelper.shared.signOut()
        isLoading = false
        checkGmailAccess()
    }

    @MainActor
    private func requestGmailAccess() {
        isLoading = true
        Task {
            do {
                _ = try await GmailAuthHelper.shared.requestGmailAccess()
                isLoading = false
                checkGmailAccess()
            } catch {
                isLoading = false
            }
        }
    }
}
