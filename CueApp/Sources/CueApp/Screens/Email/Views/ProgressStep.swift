import SwiftUI

enum StepState {
    case uncompleted
    case inProgress
    case completed
    case error
}

struct ProgressStep: View {
    let text: String
    let state: StepState

    private let iconSize: CGFloat = 16
    private let strokeWidth: CGFloat = 1.8

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                switch state {
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: iconSize))
                        .foregroundColor(.green)
                case .inProgress:
                    ActivityIndicator()
                        .frame(width: iconSize, height: iconSize)
                case .uncompleted:
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.8), lineWidth: strokeWidth)
                        .frame(width: iconSize, height: iconSize)
                case .error:
                    Circle()
                        .stroke(Color.red, lineWidth: strokeWidth)
                        .frame(width: iconSize, height: iconSize)
                    Image(systemName: "exclamationmark")
                        .font(.system(size: iconSize * 0.7))
                        .foregroundColor(.red)
                }
            }
            .frame(width: iconSize, height: iconSize)

            if state == .inProgress {
                AnimatedText(text: text)
            } else {
                Text(text)
                    .foregroundColor(getTextColor())
            }
        }
    }

    private func getTextColor() -> Color {
        switch state {
        case .completed:
            return .primary
        case .inProgress:
            return .primary
        case .uncompleted:
            return .secondary
        case .error:
            return .red
        }
    }
}

struct ProgressStep_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 20) {
            ProgressStep(text: "Completed Step", state: .completed)
            ProgressStep(text: "In Progress Step", state: .inProgress)
            ProgressStep(text: "Uncompleted Step", state: .uncompleted)
            ProgressStep(text: "Error Step", state: .error)
        }
        .padding()
    }
}
