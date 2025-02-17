import SwiftUI

struct TagView: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.15))
            .foregroundColor(.primary.opacity(0.8))
            .clipShape(Capsule())
    }
}
