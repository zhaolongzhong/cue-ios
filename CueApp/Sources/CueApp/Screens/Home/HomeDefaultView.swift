import SwiftUI
import Dependencies

struct HomeDefaultView: View {
    let sidePanelState: SidePanelState
    @ObservedObject var viewModel: HomeViewModel

    @State private var animateGreeting = false
    @State private var animateQuote = false
    @State private var animateButton = false
    @State private var isLoadingQuote = false

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text(viewModel.greeting)
                .font(.largeTitle)
                .fontWeight(.bold)
                .offset(x: animateGreeting ? 0 : -100)
                .opacity(animateGreeting ? 1 : 0)

            if let quoteOrFunFact = viewModel.quoteOrFunFact.first {
                VStack {
                    Text("\"\(quoteOrFunFact.text)\"")
                        .frame(maxWidth: 300)
                        .multilineTextAlignment(.center)
                    if let source = quoteOrFunFact.source {
                        Text(source)
                            .font(.subheadline)
                    }
                }
                .foregroundColor(.secondary)
                .offset(y: animateQuote ? 0 : 30)
                .opacity(animateQuote ? 1 : 0)
            } else if isLoadingQuote {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding()
            }

            Button(action: {
                viewModel.navigateToDestination(.cue)
            }) {
                Text("Start session")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 280)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.red.opacity(0.7)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 20)
            .offset(x: animateButton ? 0 : 100)
            .opacity(animateButton ? 1 : 0)
        }
        .padding()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateGreeting = true
            }

            if viewModel.quoteOrFunFact.isEmpty {
                isLoadingQuote = true
                Task {
                    await viewModel.fetchQuoteOrFunFact()
                    // Once quote is fetched, animate it
                    DispatchQueue.main.async {
                        isLoadingQuote = false
                        withAnimation(.easeOut(duration: 0.6)) {
                            animateQuote = true
                        }

                        // After quote animation, show button
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                            withAnimation(.easeOut(duration: 0.6)) {
                                animateButton = true
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.easeOut(duration: 0.6)) {
                        animateQuote = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.easeOut(duration: 0.6)) {
                            animateButton = true
                        }
                    }
                }
            }
        }
    }
}
