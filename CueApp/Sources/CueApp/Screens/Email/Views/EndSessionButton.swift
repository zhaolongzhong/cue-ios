import SwiftUI

struct EndSessionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("End session")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.15))
            )
        }
        .buttonStyle(.borderless)
    }
}
