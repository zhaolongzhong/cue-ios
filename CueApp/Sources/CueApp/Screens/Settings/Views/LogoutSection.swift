import SwiftUI

struct LogoutSection: View {
    let onLogout: () -> Void
    @State private var showingLogoutConfirmation = false

    var body: some View {
        Section {
            SettingsRow(
                systemIcon: "rectangle.portrait.and.arrow.right",
                title: "Log out",
                showChevron: false
            ) {
                showingLogoutConfirmation = true
            }
            .logoutConfirmation(
                isPresented: $showingLogoutConfirmation,
                onConfirm: onLogout
            )
        }
    }
}

extension View {
    func logoutConfirmation(
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        confirmationDialog(
            "Log out",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button("Log out", role: .destructive) {
                onConfirm()
            }
            Button("Cancel", role: .cancel) {
                isPresented.wrappedValue = false
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
}
