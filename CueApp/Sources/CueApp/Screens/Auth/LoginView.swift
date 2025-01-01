import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: LoginViewModel
    @State private var showSignUp = false

    init(loginViewModelFactory: @escaping () -> LoginViewModel) {
        _viewModel = StateObject(wrappedValue: loginViewModelFactory())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Text("Cue")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color.primary)
                    Text("~")
                        .font(.system(size: 50, weight: .light, design: .monospaced))
                        .foregroundColor(Color.primary.opacity(0.9))
                }
                .padding(.vertical, 36)

                Text("Welcome back")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.primary.opacity(0.8))

                VStack(spacing: 16) {
                    PlatformTextField("Email", text: $viewModel.email)
                    PlatformTextField("Password", text: $viewModel.password, textContentType: .password)
                }
                .padding(.horizontal, 48)

                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: {
                    Task {
                        await viewModel.login()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Log in")
                    }
                }
                #if os(iOS)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.Colors.secondaryBackground)
                .foregroundColor(Color.primary.opacity(0.9))
                .cornerRadius(10)
                .padding(.horizontal, 48)
                #else
                .frame(width: 80)
                .buttonStyle(.borderedProminent)
                .tint(Color.primary.opacity(0.9))
                #endif
                .disabled(viewModel.isLoading)

                Button("Forgot password?", action: {
                    // Handle forgot password
                })
                .foregroundColor(Color.primary.opacity(0.9))
                #if os(macOS)
                .buttonStyle(.plain)
                .controlSize(.small)
                #endif

                Spacer()

                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundColor(Color.primary.opacity(0.6))
                    Button("Sign up") {
                        showSignUp = true
                    }
                    .foregroundColor(Color.primary)
                    #if os(macOS)
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    #endif
                }
            }
            .background(AppTheme.Colors.background)
            .authWindowSize()
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView(signUpiewModelFactory: dependencies.viewModelFactory.makeSignUpViewModel)
            }
        }
        .tint(Color.primary.opacity(0.8))

    }
}
