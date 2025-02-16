import SwiftUI

struct UserInfoView: View {
    let email: String

    var body: some View {
            SettingsRow(
                systemName: "envelope",
                title: "Email",
                value: email,
                showChevron: false
            )
    }
}
