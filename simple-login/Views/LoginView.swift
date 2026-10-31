import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: LoginViewModel

    @FocusState private var focusedField: Field?

    @State private var isShowingPassword = false

    @State private var isShowingForgotPasswordAlert = false

    private enum Field: Hashable {
        case email
        case password
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage) {
                        viewModel.errorMessage = nil
                    }
                }

                emailField
                passwordField
                loginButton
                forgotPasswordButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(.default, value: viewModel.errorMessage)
        .alert("Forgot password?", isPresented: $isShowingForgotPasswordAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Password reset isn't part of this demo yet.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text("Sign in")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Use your account to continue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Email")

            TextField("you@example.com", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .onSubmit { focusedField = .password }
                .onChange(of: viewModel.email) { _, _ in viewModel.emailDidChange() }
                .accessibilityLabel("Email")

            validationMessage(viewModel.emailErrorMessage)
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Password")

            HStack(spacing: 8) {
                Group {
                    if isShowingPassword {
                        TextField("Password", text: $viewModel.password)
                    } else {
                        SecureField("Password", text: $viewModel.password)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .onSubmit(submit)
                .onChange(of: viewModel.password) { _, _ in viewModel.passwordDidChange() }
                .accessibilityLabel("Password")

                Button(action: togglePasswordVisibility) {
                    Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isShowingPassword ? "Hide password" : "Show password")
            }

            validationMessage(viewModel.passwordErrorMessage)
        }
    }

    private var loginButton: some View {
        Button(action: submit) {
            ZStack {
                Text("Log In")
                    .font(.headline)
                    .opacity(viewModel.isLoading ? 0 : 1)

                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.canSubmit)
        .accessibilityLabel(viewModel.isLoading ? "Signing in" : "Log in")
        .accessibilityHint(
            viewModel.isFormValid
                ? "Signs you in with the email and password you entered."
                : "Enter a valid email address and a password of at least \(LoginValidator.minimumPasswordLength) characters."
        )
    }

    private var forgotPasswordButton: some View {
        Button("Forgot password?") {
            isShowingForgotPasswordAlert = true
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .accessibilityHint("Explains how to reset your password.")
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func validationMessage(_ message: String?) -> some View {
        if let message {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .imageScale(.small)
                    .accessibilityHidden(true)

                Text(message)
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.red)
            .accessibilityElement(children: .combine)
        }
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.submit() }
    }

    private func togglePasswordVisibility() {
        let hadFocus = focusedField == .password
        isShowingPassword.toggle()

        guard hadFocus else { return }
        Task { @MainActor in
            focusedField = .password
        }
    }
}

private extension LoginView {
    static var previewViewModel: LoginViewModel {
        LoginViewModel(
            authService: MockAuthService(delay: .milliseconds(200)),
            tokenStore: InMemoryAuthTokenStore()
        )
    }
}

#Preview("Light") {
    LoginView(viewModel: LoginView.previewViewModel)
}

#Preview("Dark") {
    LoginView(viewModel: LoginView.previewViewModel)
        .preferredColorScheme(.dark)
}

#Preview("Large text") {
    LoginView(viewModel: LoginView.previewViewModel)
        .environment(\.dynamicTypeSize, .accessibility3)
}
