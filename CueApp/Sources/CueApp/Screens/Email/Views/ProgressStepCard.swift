import SwiftUI

struct ProgressStepCard: View {
    @Environment(\.colorScheme) var colorScheme
    let sectionTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sectionTitle)
                .font(.title)
                .fontWeight(.semibold)
            ProgressStepCardRowShimmer2()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

struct ProgressStepCardRowShimmer2: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<2) { _ in
                ProgressStepCardRowItem(width: 250)
                ProgressStepCardRowItem(width: 125)
                ProgressStepCardRowItem(width: 185)
                    .padding(.bottom, 16)
            }
        }
    }
}

struct ProgressStepCardRowItem: View {
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: 18)
            .padding(.vertical, 2)
            .shimmer()
    }
}
