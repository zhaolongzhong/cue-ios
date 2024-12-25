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
    @Environment(\.colorScheme) var colorScheme

    private let gradientColors: [Color] = [.blue, .purple]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: gradientColors.map { $0.opacity(colorScheme == .dark ? 0.1 : 0.05) }), 
                          startPoint: .topLeading, 
                          endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Logo and welcome section
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.linearGradient(colors: gradientColors, 
                                                           startPoint: .topLeading, 
                                                           endPoint: .bottomTrailing))
                            .padding(.top, 40)

                        Text("Welcome Back")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }

                    // Input fields
                    VStack(spacing: 20) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundStyle(.secondary)
                                TextField("you@example.com", text: $viewModel.email)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundStyle(.secondary)
                                SecureField("••••••••", text: $viewModel.password)
                                    .textContentType(.password)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    // Error message
                    if let error = viewModel.error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                        .padding(.horizontal, 24)
                    }

                    // Sign in button
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await viewModel.login()
                            }
                        }) {
                            HStack {
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
                            .background(
                                LinearGradient(gradient: Gradient(colors: gradientColors), 
                                             startPoint: .leading, 
                                             endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(viewModel.isLoading)
                        .padding(.horizontal, 24)

                        Button("Forgot Password?") {
                            // Handle forgot password
                        }
                        .font(.callout)
                        .tint(gradientColors[0])
                    }

                    Spacer(minLength: 30)

                    // Sign up section
                    VStack(spacing: 16) {
                        Divider()
                            .padding(.horizontal, 24)
                        
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .foregroundStyle(.secondary)
                            Button("Create Account") {
                                showSignUp = true
                            }
                            .fontWeight(.medium)
                            .tint(gradientColors[0])
                        }
                        .font(.callout)
                        .padding(.bottom, 20)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
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
    @Environment(\.colorScheme) var colorScheme
    
    private let gradientColors: [Color] = [.blue, .purple]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: gradientColors.map { $0.opacity(colorScheme == .dark ? 0.1 : 0.05) }), 
                          startPoint: .topLeading, 
                          endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Logo and welcome section
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundStyle(.linearGradient(colors: gradientColors, 
                                                       startPoint: .topLeading, 
                                                       endPoint: .bottomTrailing))
                        .padding(.top, 20)

                    Text("Welcome Back")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                // Input fields
                VStack(spacing: 16) {
                    // Email field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundStyle(.secondary)
                            TextField("you@example.com", text: $viewModel.email)
                        }
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(width: 280)

                    // Password field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                            SecureField("••••••••", text: $viewModel.password)
                        }
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(width: 280)
                }

                // Error message
                if let error = viewModel.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Sign in button
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await viewModel.login()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .controlSize(.small)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.medium)
                            }
                        }
                        .frame(width: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading)

                    Button("Forgot Password?") {
                        // Handle forgot password
                    }
                    .buttonStyle(.link)
                    .controlSize(.small)
                }

                Spacer()

                // Sign up section
                VStack(spacing: 12) {
                    Divider()
                    
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Create Account") {
                            showSignUp = true
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                    }
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView(signUpiewModelFactory: dependencies.viewModelFactory.makeSignUpViewModel)
        }
        .frame(width: 340, height: 480)
        .onAppear {
            setWindowSize(width: 340, height: 480)
        }
    }
}
#endif