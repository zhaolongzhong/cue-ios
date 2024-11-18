import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var viewModel = LoginViewModel()
    @State private var showSignUp = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.bottom, 20)

            Text("Welcome Back!")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 15) {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    #endif

                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.password)
            }
            .padding(.horizontal, 30)

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
            .padding(.horizontal, 30)
            .disabled(viewModel.isLoading)

            Button("Forgot Password?") {
                // Handle forgot password
            }
            .foregroundColor(.blue)

            Spacer()

            HStack {
                Text("Don't have an account?")
                Button("Sign Up") {
                    showSignUp = true
                }
                .foregroundColor(.blue)
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
        }
        .padding()
        .frame(width: 400, height: 600) // Adjust height as needed
    }
}

class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var error: String?
    @Published var isLoading = false

    @MainActor
    func login(authService: AuthService) async {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"
            return
        }

        isLoading = true
        do {
            _ = try await authService.login(email: email, password: password)
            self.error = nil // Clear error on successful login
        } catch AuthError.invalidCredentials {
            self.error = "Invalid email or password"
        } catch {
            self.error = "An error occurred. Please try again."
        }

        isLoading = false
    }
}
