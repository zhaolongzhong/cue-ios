import SwiftUI

struct LogoutButtonView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.red)
                Text("Logout")
                    .foregroundColor(.red)
            }
        }
    }
}
