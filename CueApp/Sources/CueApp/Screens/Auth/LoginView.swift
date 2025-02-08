import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: LoginViewModel
    @State private var showSignUp = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    init(loginViewModelFactory: @escaping () -> LoginViewModel) {
        _viewModel = StateObject(wrappedValue: loginViewModelFactory())
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack {
                    VStack(spacing: 24) {
                        HStack {
                            Text("Cue")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color.primary)
                            Text("~")
                                .font(.system(size: 50, weight: .light, design: .monospaced))
                        }
                        .padding(.top, 48)
                        .padding(.bottom, 32)

                        Text("Welcome back")
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.bottom, 8)

                        VStack(spacing: 16) {
                            PlatformTextField("Email", text: $viewModel.email)
                                .focused($focusedField, equals: .email)
                            PlatformTextField("Password", text: $viewModel.password, textContentType: .password)
                                .focused($focusedField, equals: .password)
                        }

                        if let error = viewModel.error {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.top, 4)
                        }

                        VStack(spacing: 12) {
                            PlatformButton(
                                action: {
                                    focusedField = nil
                                    await viewModel.login()
                                },
                                isLoading: viewModel.isLoading
                            ) {
                                Text("Log in")
                            }

                            PlatformButton(
                                action: {
                                    focusedField = nil
                                },
                                style: .secondary
                            ) {
                                Text("Forgot Password?")
                            }
                        }
                        .padding(.top, 8)
                    }

                    Spacer()

                    VStack(spacing: 16) {
                        GoogleSignInButton(style: .wide, action: handleSignInButton)
                            .frame(maxWidth: 280)

                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundColor(Color.primary.opacity(0.6))
                            Button("Sign up") {
                                focusedField = nil
                                showSignUp = true
                            }
                            .foregroundColor(Color.primary)
                            #if os(macOS)
                            .buttonStyle(.plain)
                            .controlSize(.small)
                            #endif
                        }
                    }
                    .padding(.bottom, 32)
                }
                #if os(iOS)
                .frame(minHeight: UIScreen.main.bounds.height - 100)
                #endif
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(AppTheme.Colors.background)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView(signUpiewModelFactory: dependencies.viewModelFactory.makeSignUpViewModel)
            }
        }
        .tint(Color.primary.opacity(0.8))
    }

    func handleSignInButton() {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }

        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController) { signInResult, error in
                guard let result = signInResult else {
                    viewModel.handleGoogleSignInError(error)
                    return
                }
                Task {
                    await viewModel.handleGoogleSignIn(result)
                }
            }
        #elseif os(macOS)
        guard let window = NSApplication.shared.windows.first else {
            return
        }

        GIDSignIn.sharedInstance.signIn(
            withPresenting: window) { signInResult, error in
                guard let result = signInResult else {
                    viewModel.handleGoogleSignInError(error)
                    return
                }
                Task {
                    await viewModel.handleGoogleSignIn(result)
                }
            }
        #endif
    }
}
