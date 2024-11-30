import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var viewModel = LoginViewModel()
    @State private var showSignUp = false

    var body: some View {
        #if os(iOS)
        iOSLoginContent
        #else
        macOSLoginContent
        #endif
    }

    // MARK: - iOS Content
    private var iOSLoginContent: some View {
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
                    #if os(iOS)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    #endif

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
                    await viewModel.login(authService: authService)
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
            SignUpView()
        }
    }

    // MARK: - macOS Content
    private var macOSLoginContent: some View {
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
                        await viewModel.login(authService: authService)
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
            #if os(macOS)
            .buttonStyle(.link)
            #endif
            .controlSize(.small)

            Spacer()

            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .font(.caption)
                Button("Sign Up") {
                    showSignUp = true
                }
                #if os(macOS)
                .buttonStyle(.link)
                #endif
                .controlSize(.small)
            }
        }
        .padding(24)
        .frame(width: 340, height: 480)
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }
}
