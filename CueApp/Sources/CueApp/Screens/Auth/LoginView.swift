import SwiftUI

// Main View
struct LoginView: View {
    @StateObject private var loginViewModel: LoginViewModel
    @State private var showSignUp = false

    init(loginViewModelFactory: @escaping () -> LoginViewModel) {
        _loginViewModel = StateObject(wrappedValue: loginViewModelFactory())
    }

    var body: some View {
        LoginContent(
            viewModel: loginViewModel,
            showSignUp: $showSignUp
        )
    }
}

// Content View
private struct LoginContent: View {
    @StateObject var viewModel: LoginViewModel
    @Binding var showSignUp: Bool

    init(viewModel: LoginViewModel, showSignUp: Binding<Bool>) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _showSignUp = showSignUp
    }

    var body: some View {
        #if os(iOS)
        iOSLoginContent(
            viewModel: viewModel,
            showSignUp: $showSignUp
        )
        #else
        macOSLoginContent(
            viewModel: viewModel,
            showSignUp: $showSignUp
        )
        #endif
    }
}

// iOS Content
#if os(iOS)
private struct iOSLoginContent: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @ObservedObject var viewModel: LoginViewModel
    @Binding var showSignUp: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Welcome Back!")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
            }
            .padding(.horizontal, 32)

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
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal, 32)
            .disabled(viewModel.isLoading)

            Button("Forgot Password?", action: {
                // Handle forgot password
            })
            .foregroundColor(.blue)

            Spacer()

            HStack(spacing: 4) {
                Text("Don't have an account?")
                Button("Sign Up") {
                    showSignUp = true
                }
                .foregroundColor(.blue)
            }
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(signUpiewModelFactory: dependencies.viewModelFactory.makeSignUpViewModel)
        }
    }
}
#endif

// macOS Content
#if os(macOS)
private struct macOSLoginContent: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @ObservedObject var viewModel: LoginViewModel
    @Binding var showSignUp: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
                .padding(.bottom, 10)

            Text("Welcome Back!")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }

            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack(spacing: 12) {
                Button("Sign In") {
                    Task {
                        await viewModel.login()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .frame(width: 80)

                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding(.top, 8)

            Button("Forgot Password?") {
                // Handle forgot password
            }
            .buttonStyle(.link)
            .controlSize(.small)

            Spacer()

            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .font(.caption)
                Button("Sign Up") {
                    showSignUp = true
                }
                .buttonStyle(.link)
                .controlSize(.small)
            }
        }
        .padding(24)
        .sheet(isPresented: $showSignUp) {
            SignUpView(signUpiewModelFactory: dependencies.viewModelFactory.makeSignUpViewModel)
        }
        .frame(minWidth: 340, minHeight: 480)
        .onAppear {
            setWindowSize(width: 340, height: 480)
        }
    }
}
#endif
