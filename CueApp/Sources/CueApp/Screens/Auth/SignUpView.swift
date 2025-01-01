import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
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
                PlatformTextField("Email", text: $viewModel.email)
                PlatformTextField("Password", text: $viewModel.password, textContentType: .password)
                PlatformTextField("Confirm password", text: $viewModel.confirmPassword, textContentType: .password)
                PlatformTextField("Invite code (optional)", text: $viewModel.inviteCode)
            }
            .padding(.horizontal, 48)

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

            Spacer()

            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundColor(Color.primary.opacity(0.6))
                Button("Log in") {
                    dismiss()
                }
                .foregroundColor(Color.primary)
                #if os(macOS)
                .buttonStyle(.plain)
                .controlSize(.small)
                #endif
            }
        }
        .navigationTitle("Sign up")
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .imageScale(.large)
                }
            }

        }
        #endif
        #if os(iOS)
        .navigationBarTitleDisplayMode(.automatic)
        #endif
        .background(AppTheme.Colors.background)
        .authWindowSize()
    }
}
