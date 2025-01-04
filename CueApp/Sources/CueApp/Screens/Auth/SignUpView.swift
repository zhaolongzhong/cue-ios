import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: SignUpViewModel
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, confirmPassword, inviteCode
    }

    init(signUpiewModelFactory: @escaping () -> SignUpViewModel) {
        _viewModel = StateObject(wrappedValue: signUpiewModelFactory())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                VStack(spacing: 24) {
                    Text("Create your account")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 16)

                    VStack(spacing: 16) {
                        PlatformTextField("Email", text: $viewModel.email)
                            .focused($focusedField, equals: .email)
                        PlatformTextField("Password", text: $viewModel.password, textContentType: .password)
                            .focused($focusedField, equals: .password)
                        PlatformTextField("Confirm password", text: $viewModel.confirmPassword, textContentType: .password)
                            .focused($focusedField, equals: .confirmPassword)
                        PlatformTextField("Invite code (optional)", text: $viewModel.inviteCode)
                            .focused($focusedField, equals: .inviteCode)
                    }

                    if let error = viewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 4)
                    }

                    PlatformButton(
                        action: {
                            focusedField = nil
                            await viewModel.signup()
                        },
                        isLoading: viewModel.isLoading
                    ) {
                        Text("Sign up")
                    }
                    .padding(.top, 8)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundColor(Color.primary.opacity(0.6))
                    Button("Log in") {
                        focusedField = nil
                        dismiss()
                    }
                    .foregroundColor(Color.primary)
                    #if os(macOS)
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    #endif
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
        .authWindowSize()
        .defaultNavigationBar(title: "Sign up")
    }
}
