import SwiftUI
import Dependencies

struct HomeDefaultView: View {
    @ObservedObject var viewModel: HomeViewModel
    let onNewSession: () -> Void

    @State private var animateGreeting = false
    @State private var animateQuote = false
    @State private var animateButton = false
    @State private var isLoadingQuote = false

    var body: some View {
        ZStack {
            backgroundView
            contentView
        }
        .onAppear(perform: startAnimations)
    }

    private var backgroundView: some View {
        Group {
            #if os(macOS)
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
            #endif
            AppTheme.Colors.background
                .opacity(0.5)
                .ignoresSafeArea()
        }
    }

    private var contentView: some View {
        VStack(alignment: .center, spacing: 20) {
            greetingView
            quoteView
            sessionButton
        }
        .padding()
    }

    private var greetingView: some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.greeting.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.title)
                    .fontWeight(.bold)
                    .opacity(animateGreeting ? 1 : 0)
                    .animation(
                        .easeOut(duration: 0.3).delay(Double(index) * 0.05),
                        value: animateGreeting
                    )
            }
        }
    }

    private var quoteView: some View {
        Group {
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
                .offset(y: animateQuote ? 0 : 30)
                .opacity(animateQuote ? 1 : 0)
            } else if isLoadingQuote {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding()
            }
        }
    }

    private var sessionButton: some View {
        Button(action: onNewSession) {
            Text("Start session")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 24)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.cyan.opacity(0.9),
                            Color.blue.opacity(0.9),
                            Color.purple.opacity(0.9),
                            Color.red.opacity(0.9)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.top, 20)
        .offset(y: animateQuote ? 0 : 30)
        .opacity(animateButton ? 1 : 0)
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.6)) { animateGreeting = true }

        if viewModel.quoteOrFunFact.isEmpty {
            isLoadingQuote = true
            Task {
                await viewModel.fetchQuoteOrFunFact()
                await MainActor.run {
                    isLoadingQuote = false
                    withAnimation(.easeOut(duration: 0.6)) { animateQuote = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.easeOut(duration: 0.6)) { animateButton = true }
                    }
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.6)) { animateQuote = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.easeOut(duration: 0.6)) { animateButton = true }
                }
            }
        }
    }
}
