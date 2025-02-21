import SwiftUI

struct UserInfoView: View {
    let email: String

    var body: some View {
            SettingsRow(
                systemIcon: "envelope",
                title: "Email",
                value: email,
                showChevron: false
            )
    }
}
