import Foundation
import Testing

@testable import simple_login

@Suite("LoginViewModel failures and session lifetime")
struct LoginViewModelFailureTests {

    private func makeSUT(
        service: any AuthServiceProtocol = MockAuthService(delay: .zero),
        storedToken: String? = nil
    ) -> (viewModel: LoginViewModel, store: InMemoryAuthTokenStore) {
        let store = InMemoryAuthTokenStore(token: storedToken)
        return (LoginViewModel(authService: service, tokenStore: store), store)
    }

    private func fillValidCredentials(_ viewModel: LoginViewModel) {
        viewModel.email = MockAuthService.validEmail
        viewModel.password = MockAuthService.validPassword
    }

    @Test("failed login shows the human-readable error and clears the password")
    func failedLoginSetsErrorMessage() async {
        let sut = makeSUT()
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = "WrongPassword1"

        await sut.viewModel.submit()

        #expect(sut.viewModel.isAuthenticated == false)
        #expect(sut.viewModel.errorMessage == AuthError.genericInvalidCredentials.errorDescription)
        #expect(sut.viewModel.errorMessage?.contains("Error Domain") == false)
        #expect(sut.viewModel.password.isEmpty, "the credential must not survive a failed attempt")
        #expect(sut.store.loadToken() == nil)
    }

    @Test("a transport failure is reported as a network problem, never raw error text")
    func transportFailureIsSanitised() async {
        let sut = makeSUT(service: StubAuthService(result: .failure(URLError(.notConnectedToInternet))))
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword

        await sut.viewModel.submit()

        #expect(sut.viewModel.errorMessage == AuthError.networkUnavailable.errorDescription)
    }

    @Test("loading is true during the request and false afterwards")
    func loadingStateTracksRequestLifecycle() async {
        let service = SuspendedAuthService()
        let sut = makeSUT(service: service)
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword

        let submission = Task { await sut.viewModel.submit() }

        await waitUntil { service.hasReceivedRequest }
        #expect(sut.viewModel.isLoading)
        #expect(sut.viewModel.canSubmit == false, "the button must be inert while loading")

        service.resume(returning: AuthToken(accessToken: "token"))
        await submission.value

        #expect(sut.viewModel.isLoading == false)
        #expect(sut.viewModel.isAuthenticated)
    }

    @Test("overlapping submissions are ignored while one is in flight")
    func duplicateSubmissionsAreIgnored() async {
        let service = SuspendedAuthService()
        let sut = makeSUT(service: service)
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword

        let submission = Task { await sut.viewModel.submit() }
        await waitUntil { service.hasReceivedRequest }
        await sut.viewModel.submit()

        #expect(service.requestCount == 1)

        service.resume(returning: AuthToken(accessToken: "token"))
        await submission.value
    }

    @Test("a token in the store skips the login screen on launch")
    func storedTokenRestoresSession() {
        let sut = makeSUT(storedToken: "stored-token")

        #expect(sut.viewModel.isAuthenticated)
        #expect(sut.viewModel.authToken?.accessToken == "stored-token")
    }

    @Test("log out clears the stored token and resets the form")
    func logOutClearsSession() async {
        let sut = makeSUT()
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword
        await sut.viewModel.submit()

        await sut.viewModel.logOut()

        #expect(sut.viewModel.isAuthenticated == false)
        #expect(sut.store.loadToken() == nil)
        #expect(sut.viewModel.email.isEmpty)
        #expect(sut.viewModel.password.isEmpty)
        #expect(sut.viewModel.emailErrorMessage == nil)
        #expect(sut.viewModel.currentUser == nil)
        #expect(sut.viewModel.signedInName.isEmpty)
    }

    @Test("log out revokes the session on the server")
    func logOutRevokesSessionServerSide() async {
        let service = SpyAuthService()
        let sut = makeSUT(service: service)
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword
        await sut.viewModel.submit()

        await sut.viewModel.logOut()

        #expect(service.revokedTokens == ["spy-session-token"])
    }

    @Test("log out clears this device before it talks to the server")
    func logOutIsLocalFirst() async {
        let service = SpyAuthService()
        let sut = makeSUT(service: service)
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword
        await sut.viewModel.submit()

        var wasAuthenticatedDuringRevocation: Bool?
        var storedTokenDuringRevocation: String?
        service.whenRevoking = {
            wasAuthenticatedDuringRevocation = sut.viewModel.isAuthenticated
            storedTokenDuringRevocation = sut.store.loadToken()
        }

        await sut.viewModel.logOut()

        #expect(wasAuthenticatedDuringRevocation == false)
        #expect(storedTokenDuringRevocation == nil)
        #expect(service.revokedTokens == ["spy-session-token"])
    }

    @Test("a 422's field issues are shown under the fields they name")
    func serverFieldIssuesAreRenderedInline() async {
        let service = SpyAuthService()
        service.loginResult = .failure(AuthError.validation(fieldIssues: [
            "email": "is not a valid email address",
            "password": "is required",
        ]))
        let sut = makeSUT(service: service)
        fillValidCredentials(sut.viewModel)

        await sut.viewModel.submit()

        #expect(service.loginCallCount == 1, "the request must have reached the service")
        #expect(sut.viewModel.emailErrorMessage == "is not a valid email address")
        #expect(sut.viewModel.passwordErrorMessage == "is required")
        #expect(sut.viewModel.errorMessage == nil)
    }

    @Test("a 422 naming only fields this screen does not show falls back to the banner")
    func unplaceableServerIssuesUseTheBanner() async {
        let service = SpyAuthService()
        service.loginResult = .failure(AuthError.validation(fieldIssues: ["displayName": "must be 2 to 60 characters"]))
        let sut = makeSUT(service: service)
        fillValidCredentials(sut.viewModel)

        await sut.viewModel.submit()

        #expect(sut.viewModel.emailErrorMessage == nil)
        #expect(sut.viewModel.errorMessage == AuthError.validation(fieldIssues: [:]).errorDescription)
    }

    @Test("a server issue is dropped once the user edits that field")
    func editingAFieldClearsItsServerIssue() async {
        let service = SpyAuthService()
        service.loginResult = .failure(AuthError.validation(fieldIssues: ["email": "is not a valid email address"]))
        let sut = makeSUT(service: service)
        fillValidCredentials(sut.viewModel)

        await sut.viewModel.submit()
        #expect(sut.viewModel.emailErrorMessage == "is not a valid email address")

        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.emailDidChange()

        #expect(sut.viewModel.emailErrorMessage == nil)
    }

    @Test("a 422 that blames the password does not wipe the password")
    func serverPasswordIssueKeepsThePassword() async {
        let service = SpyAuthService()
        service.loginResult = .failure(AuthError.validation(fieldIssues: ["password": "is required"]))
        let sut = makeSUT(service: service)
        fillValidCredentials(sut.viewModel)

        await sut.viewModel.submit()

        #expect(sut.viewModel.password == MockAuthService.validPassword)
    }

    @Test("a new attempt clears the previous server verdict")
    func newAttemptClearsServerIssues() async {
        let service = SpyAuthService()
        service.loginResult = .failure(AuthError.validation(fieldIssues: ["email": "is not a valid email address"]))
        let sut = makeSUT(service: service)
        fillValidCredentials(sut.viewModel)

        await sut.viewModel.submit()
        #expect(sut.viewModel.emailErrorMessage == "is not a valid email address")

        service.loginResult = .success(AuthToken(accessToken: "second-try"))
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword
        await sut.viewModel.submit()

        #expect(sut.viewModel.isAuthenticated)
        #expect(sut.viewModel.emailErrorMessage == nil)
    }

    @Test("inline validation messages stay hidden until the field is touched")
    func validationMessagesRequireInteraction() {
        let sut = makeSUT()

        #expect(sut.viewModel.emailErrorMessage == nil)
        #expect(sut.viewModel.passwordErrorMessage == nil)

        sut.viewModel.emailDidChange()
        sut.viewModel.passwordDidChange()

        #expect(sut.viewModel.emailErrorMessage == LoginValidator.emailErrorMessage(for: ""))
        #expect(sut.viewModel.passwordErrorMessage == "Enter your password.")
    }
}
