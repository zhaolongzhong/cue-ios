import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: SignUpViewModel

    init(signUpiewModelFactory: @escaping () -> SignUpViewModel) {
        _viewModel = StateObject(wrappedValue: signUpiewModelFactory())
    }

    var body: some View {
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
            .padding(.vertical, 50)

            Text("Create your account")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.primary.opacity(0.8))

            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    #if os(macOS)
                    .frame(width: 280)
                    #else
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    #endif

                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    #if os(macOS)
                    .frame(width: 280)
                    #endif

                SecureField("Confirm password", text: $viewModel.confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)
                    #if os(macOS)
                    .frame(width: 280)
                    #endif

                #if os(macOS)
                TextField("Invite code (optional)", text: $viewModel.inviteCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
                #endif
            }
            .padding(.horizontal, 32)

            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                Task {
                    await viewModel.signup()
                }
            }) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign up")
                        #if os(iOS)
                        .fontWeight(.semibold)
                        #endif
                }
            }
            #if os(iOS)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground).opacity(0.1))
            .background(
                Color.primary.opacity(0.9)
            )
            .foregroundColor(Color(.systemBackground))
            .cornerRadius(10)
            .padding(.horizontal, 32)
            #else
            .frame(width: 80)
            .buttonStyle(.borderedProminent)
            .tint(Color.primary.opacity(0.9))
            #endif
            .disabled(viewModel.isLoading)

            Spacer()

            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundColor(Color.primary.opacity(0.8))
                Button("Log in") {
                    presentationMode.wrappedValue.dismiss()
                }
                #if os(iOS)
                .foregroundColor(Color.primary)
                #else
                .buttonStyle(.plain)
                .controlSize(.small)
                #endif
            }
            .padding(.bottom, 20)
        }
        .authWindowSize()
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        #else

        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        #endif
    }
}
