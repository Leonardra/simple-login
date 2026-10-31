import Foundation
import Observation

@MainActor
@Observable
final class LoginViewModel {

    var email = ""
    var password = ""

    private(set) var hasEditedEmail = false
    private(set) var hasEditedPassword = false

    private(set) var isLoading = false

    var errorMessage: String?

    private(set) var authToken: AuthToken?

    private(set) var currentUser: AuthUser?

    var isAuthenticated: Bool { authToken != nil }

    var signedInName: String { currentUser?.displayName ?? "" }

    var signedInEmail: String { currentUser?.email ?? "" }

    private(set) var serverEmailIssue: String?
    private(set) var serverPasswordIssue: String?

    private let authService: any AuthServiceProtocol
    private let tokenStore: any AuthTokenStore

    init(
        authService: any AuthServiceProtocol,
        tokenStore: any AuthTokenStore = KeychainAuthTokenStore()
    ) {
        self.authService = authService
        self.tokenStore = tokenStore

        if let stored = tokenStore.loadToken(), !stored.isEmpty {
            self.authToken = AuthToken(accessToken: stored)
        }
    }

    var isEmailValid: Bool { LoginValidator.isValidEmail(email) }

    var isPasswordValid: Bool { LoginValidator.isValidPassword(password) }

    var isFormValid: Bool { isEmailValid && isPasswordValid }

    var canSubmit: Bool { isFormValid && !isLoading }

    var emailErrorMessage: String? {
        if let serverEmailIssue { return serverEmailIssue }
        guard hasEditedEmail else { return nil }
        return LoginValidator.emailErrorMessage(for: email)
    }

    var passwordErrorMessage: String? {
        if let serverPasswordIssue { return serverPasswordIssue }
        guard hasEditedPassword else { return nil }
        return LoginValidator.passwordErrorMessage(for: password)
    }

    func emailDidChange() {
        hasEditedEmail = true
        serverEmailIssue = nil
    }

    func passwordDidChange() {
        hasEditedPassword = true
        serverPasswordIssue = nil
    }

    func submit() async {
        guard !isLoading else { return }

        hasEditedEmail = true
        hasEditedPassword = true

        let normalizedEmail = LoginValidator.trimmedEmail(email)
        email = normalizedEmail

        guard isFormValid else { return }

        errorMessage = nil
        serverEmailIssue = nil
        serverPasswordIssue = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await authService.login(email: normalizedEmail, password: password)
            tokenStore.saveToken(token.accessToken)
            authToken = token
            currentUser = token.user
        } catch {
            let authError = AuthError.from(error)

            if case .validation(let issues) = authError, applyServerFieldIssues(issues) {
                errorMessage = nil
            } else {
                errorMessage = authError.errorDescription
            }

            if serverPasswordIssue == nil {
                password = ""
            }
        }
    }

    func logOut() async {
        let session = authToken
        clearLocalSession()

        guard let session else { return }
        await authService.revokeSession(session)
    }

    private func clearLocalSession() {
        tokenStore.clearToken()
        authToken = nil
        currentUser = nil
        email = ""
        password = ""
        errorMessage = nil
        serverEmailIssue = nil
        serverPasswordIssue = nil
        hasEditedEmail = false
        hasEditedPassword = false
    }

    private func applyServerFieldIssues(_ issues: [String: String]) -> Bool {
        guard !issues.isEmpty else { return false }

        let normalized = Dictionary(
            issues.map { ($0.key.lowercased(), $0.value) }
        ) { first, _ in first }

        var placed = false

        if let issue = normalized["email"] {
            serverEmailIssue = issue
            hasEditedEmail = true
            placed = true
        }

        if let issue = normalized["password"] {
            serverPasswordIssue = issue
            hasEditedPassword = true
            placed = true
        }

        return placed
    }
}