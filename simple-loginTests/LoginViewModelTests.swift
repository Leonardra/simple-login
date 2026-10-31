import Foundation
import Testing

@testable import simple_login

@Suite("LoginViewModel")
struct LoginViewModelTests {

    private func makeSUT(
        service: any AuthServiceProtocol = MockAuthService(delay: .zero),
        storedToken: String? = nil
    ) -> (viewModel: LoginViewModel, store: InMemoryAuthTokenStore) {
        let store = InMemoryAuthTokenStore(token: storedToken)
        return (LoginViewModel(authService: service, tokenStore: store), store)
    }

    @Test("invalid email keeps the Log In button disabled")
    func invalidEmailDisablesLogin() {
        let sut = makeSUT()
        sut.viewModel.email = "not-an-email"
        sut.viewModel.password = MockAuthService.validPassword

        #expect(sut.viewModel.isEmailValid == false)
        #expect(sut.viewModel.isFormValid == false)
        #expect(sut.viewModel.canSubmit == false)
    }

    @Test("password shorter than 8 characters keeps the Log In button disabled")
    func shortPasswordDisablesLogin() {
        let sut = makeSUT()
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = String(repeating: "a", count: LoginValidator.minimumPasswordLength - 1)

        #expect(sut.viewModel.isPasswordValid == false)
        #expect(sut.viewModel.canSubmit == false)
    }

    @Test("valid credentials enable the Log In button")
    func validCredentialsEnableLogin() {
        let sut = makeSUT()
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword

        #expect(sut.viewModel.canSubmit)
    }

    @Test("an email with surrounding whitespace is still accepted")
    func whitespacePaddedEmailIsAccepted() {
        let sut = makeSUT()
        sut.viewModel.email = "  \(MockAuthService.validEmail)\n"
        sut.viewModel.password = MockAuthService.validPassword

        #expect(sut.viewModel.canSubmit)
    }

    @Test("successful login sets the authenticated state and persists the token")
    func successfulLoginAuthenticates() async {
        let sut = makeSUT()
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword

        await sut.viewModel.submit()

        #expect(sut.viewModel.isAuthenticated)
        #expect(sut.viewModel.authToken?.accessToken == "mock-session-token")
        #expect(sut.viewModel.errorMessage == nil)
        #expect(sut.store.loadToken() == "mock-session-token")
    }

    @Test("successful login exposes the profile for Home to greet the user with")
    func successfulLoginCapturesProfile() async {
        let sut = makeSUT()
        sut.viewModel.email = MockAuthService.validEmail
        sut.viewModel.password = MockAuthService.validPassword

        await sut.viewModel.submit()

        #expect(sut.viewModel.currentUser?.displayName == MockAuthService.displayName)
        #expect(sut.viewModel.signedInName == MockAuthService.displayName)
        #expect(sut.viewModel.signedInEmail == MockAuthService.validEmail)
    }

    @Test("the email is trimmed before it is handed to the service")
    func emailIsTrimmedBeforeSubmission() async {
        let service = SuspendedAuthService()
        let sut = makeSUT(service: service)
        sut.viewModel.email = "  \(MockAuthService.validEmail)  "
        sut.viewModel.password = MockAuthService.validPassword

        let submission = Task { await sut.viewModel.submit() }
        await waitUntil { service.hasReceivedRequest }

        #expect(service.receivedEmail == MockAuthService.validEmail)
        #expect(sut.viewModel.email == MockAuthService.validEmail)

        service.resume(returning: AuthToken(accessToken: "token"))
        await submission.value
    }
}
