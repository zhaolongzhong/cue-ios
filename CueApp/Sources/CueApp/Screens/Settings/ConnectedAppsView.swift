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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                gmailRow
            }
            .padding()
            .scrollContentBackground(.hidden)
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
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 300)
        #endif
        .defaultNavigationBar(title: "Connected Apps")
        .onAppear(perform: checkGmailAccess)
    }

    var gmailRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(
                    title: { Text("Gmail") },
                    icon: { Image(systemName: "envelope") }
                )
                Spacer()

                CapsuleOutlineButton(
                    title: gmailGranted ? "Disconnect" : "Connect",
                    foregroundColor: gmailGranted ? .red : .primary,
                    strokeColor: gmailGranted ? .red : .secondary
                ) {
                    if gmailGranted {
                        showingRemoveAlert = true
                    } else {
                        requestGmailAccess()
                    }
                }
            }
            Text("Read, send, reply and organize your emails.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.all, 8)
        #if os(macOS)
        .background(AppTheme.Colors.separator.opacity(0.5))
        #else
        .background(AppTheme.Colors.secondaryBackground.opacity(0.2))
        #endif
        .cornerRadius(8)
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
