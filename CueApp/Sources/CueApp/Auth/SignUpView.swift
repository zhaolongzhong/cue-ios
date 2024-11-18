import SwiftUI

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = SignUpViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)

                Text("Create Account")
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
                        .textContentType(.newPassword)

                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.newPassword)

                    TextField("Invite Code (Optional)", text: $viewModel.inviteCode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        }
                .padding(.horizontal, 30)

                if let error = viewModel.error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button(action: {
                    Task {
                        await viewModel.signUp()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign Up")
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

                Spacer()

                HStack {
                    Text("Already have an account?")
                    Button("Sign In") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
//                            dismiss()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
//                            dismiss()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    #endif
            }
//            .navigationBarItems(leading: Button("Cancel") {
//                presentationMode.wrappedValue.dismiss()
//            })
        }
    }
}

class SignUpViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var inviteCode = ""
    @Published var error: String?
    @Published var isLoading = false

    @MainActor
    func signUp() async {
        guard !email.isEmpty, !password.isEmpty else {
            error = "Please fill in all required fields"
            return
        }

        guard password == confirmPassword else {
            error = "Passwords do not match"
            return
        }

        guard password.count >= 8 else {
            error = "Password must be at least 8 characters"
            return
        }

        isLoading = true
        error = nil

        do {
            let authService = AuthService()
            _ = try await authService.signup(
                email: email,
                password: password,
                inviteCode: inviteCode.isEmpty ? nil : inviteCode
            )
        } catch AuthError.emailAlreadyExists {
            error = "Email already exists"
        } catch {
//            error = "An error occurred. Please try again."
        }

        isLoading = false
    }
}
