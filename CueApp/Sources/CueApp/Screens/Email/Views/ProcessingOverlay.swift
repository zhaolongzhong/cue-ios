import SwiftUI

struct AnimatedDescriptionText: View {
    let description: String

    var body: some View {
        ZStack {
            AnyView(
                Text(description)
                    .font(.headline)
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity.combined(with: .move(edge: .top))
            ))
            .id(description) // Forces view recreation
        }
        .animation(.easeInOut(duration: 0.3), value: description)
    }
}

struct ProcessingOverlay: View {
    @ObservedObject var viewModel: EmailScreenViewModel

    var body: some View {
        ZStack {
            BackgroundContainer()
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.bottom, 10)
                AnimatedDescriptionText(description: viewModel.processingState.description)
                progressSteps
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var progressSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Getting tasks step
            ProgressStep(
                text: "Getting tasks from inbox",
                state: getStepState(for: .gettingInbox)
            )
            // Organizing tasks step
            ProgressStep(
                text: "Organizing tasks",
                state: getStepState(for: .organizingTasks)
            )
            // Analyzing messages step
            ProgressStep(
                text: "Analyzing messages",
                state: getStepState(for: .analyzingMessages)
            )
            // Almost ready step
            ProgressStep(
                text: "Almost ready",
                state: getStepState(for: .almostReady)
            )
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func getStepState(for step: ProcessingState) -> StepState {
        switch viewModel.processingState {
        case .idle:
            return .uncompleted
        case .gettingInbox:
            return step == .gettingInbox ? .inProgress :
                   step == .idle ? .completed : .uncompleted
        case .organizingTasks:
            return step == .organizingTasks ? .inProgress :
                   step == .gettingInbox || step == .idle ? .completed : .uncompleted
        case .analyzingMessages:
            return step == .analyzingMessages ? .inProgress :
                   step == .almostReady ? .uncompleted : .completed
        case .almostReady:
            return step == .almostReady ? .inProgress : .completed
        case .ready:
            return .completed
        case .error:
            return .error
        }
    }
}
