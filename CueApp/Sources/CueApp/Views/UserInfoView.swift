import SwiftUI

struct UserInfoView: View {
    let email: String
    let name: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text(email)
                .font(.headline)
            if let name = name {
                Text(name)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}
