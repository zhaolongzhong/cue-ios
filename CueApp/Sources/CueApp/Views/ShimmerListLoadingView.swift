import SwiftUI

struct ShimmerListLoadingView: View {
    var body: some View {
        List {
            ForEach(0..<5) { _ in
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 24, height: 24)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 16)
                    Spacer()
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.08))
                )
                .shimmer()
            }
        }
    }
}
