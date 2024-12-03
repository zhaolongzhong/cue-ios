import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SignUpView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        let viewModel = dependencies.viewModelFactory.makeSignUpViewModel()
        SignUpContent(
            viewModel: viewModel,
            presentationMode: presentationMode
        )
    }
}

private struct SignUpContent: View {
    @ObservedObject var viewModel: SignUpViewModel
    let presentationMode: Binding<PresentationMode>

    var body: some View {
        #if os(iOS)
        iOSContent(
            viewModel: viewModel,
            presentationMode: presentationMode
        )
        #else
        macOSContent(
            viewModel: viewModel,
            presentationMode: presentationMode
        )
        #endif
    }
}

// MARK: - iOS Content
private struct iOSContent: View {
    @ObservedObject var viewModel: SignUpViewModel
   let presentationMode: Binding<PresentationMode>
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.top, 20)

                Text("Create Account")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        #if os(iOS)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        #endif

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)

                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                }
                .padding(.horizontal, 32)

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
                .padding(.horizontal, 32)
                .disabled(viewModel.isLoading)

                Spacer()

                HStack(spacing: 4) {
                    Text("Already have an account?")
                    Button("Sign In") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.bottom, 20)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            #endif
        }
    }
}

    // MARK: - macOS Content
private struct macOSContent: View {
    @ObservedObject var viewModel: SignUpViewModel
    let presentationMode: Binding<PresentationMode>
    var body: some View {
        VStack(spacing: 16) { // Reduced spacing from 20 to 16
            Image(systemName: "person.crop.circle.badge.plus")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60) // Reduced from 80 to 60
                .foregroundColor(.blue)
                .padding(.top, 12) // Reduced from 16 to 12

            Text("Create Account")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)

                TextField("Invite Code (Optional)", text: $viewModel.inviteCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }

            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack(spacing: 12) {
                Button("Sign Up") {
                    Task {
                        await viewModel.signUp()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .frame(width: 100)

                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding(.top, 8)

            Spacer()

            HStack(spacing: 4) {
                Text("Already have an account?")
                    .font(.caption)
                Button("Sign In") {
                    presentationMode.wrappedValue.dismiss()
                }
                #if os(macOS)
                .buttonStyle(.link)
                #endif
                .controlSize(.small)
            }
            .padding(.bottom, 16)
        }
        .padding(20) // Reduced from 24 to 20
        .frame(width: 340, height: 460) // Reduced from 520 to 460
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
