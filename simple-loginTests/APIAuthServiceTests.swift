import Foundation
import Testing

@testable import simple_login

@Suite("APIAuthService", .serialized)
struct APIAuthServiceTests {

    private static let baseURL = URL(string: "https://nutmtrainingbackend.dataalcomms.com/v1")!

    private static let sessionJSON = #"""
    {"token":"ajo_sess_25f7ffbb8a4255cbf69ef266f0ee6e03","expiresAt":"2026-10-30T21:59:06Z","user":{"id":"3b241101-e2bb-4255-8caf-4136c566a962","displayName":"Adaeze Okonkwo","email":"adaeze.okonkwo@nutm.edu.ng","avatarUrl":null,"createdAt":"2026-08-13T04:37:46Z"},"refreshToken":"ajo_refr_4aaa93308073977788240d6d657e1b35","refreshExpiresAt":"2026-11-22T21:59:06Z"}
    """#

    private static let unauthorizedJSON =
        #"{"code":"unauthorized","message":"That email and password don\u2019t match."}"#

    private static let validationJSON = #"""
    {"code":"validation_failed","message":"One or more fields are invalid.","details":[{"field":"email","issue":"is not a valid email address"},{"field":"password","issue":"is required"}]}
    """#

    private func makeSUT(
        statusCode: Int = 200,
        body: String = sessionJSON,
        headers: [String: String] = [:],
        failingWith transportError: URLError? = nil
    ) -> (service: APIAuthService, recorder: RequestRecorder) {
        let recorder = RequestRecorder()

        StubURLProtocol.handler = { request in
            recorder.record(request)
            if let transportError { throw transportError }
            return (
                StubURLProtocol.response(url: request.url!, statusCode: statusCode, headers: headers),
                Data(body.utf8)
            )
        }

        let service = APIAuthService(baseURL: Self.baseURL, session: StubURLProtocol.makeSession())
        return (service, recorder)
    }

    private func loginError(
        from service: APIAuthService,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async -> AuthError? {
        do {
            _ = try await service.login(
                email: MockAuthService.validEmail,
                password: MockAuthService.validPassword
            )
            Issue.record("expected the login to fail", sourceLocation: sourceLocation)
            return nil
        } catch let error as AuthError {
            return error
        } catch {
            Issue.record("expected an AuthError, got \(error)", sourceLocation: sourceLocation)
            return nil
        }
    }

    @Test("login posts JSON credentials to the documented path")
    func loginBuildsContractRequest() async throws {
        let sut = makeSUT()

        _ = try await sut.service.login(
            email: MockAuthService.validEmail,
            password: MockAuthService.validPassword
        )

        let request = try #require(sut.recorder.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "\(Self.baseURL.absoluteString)/auth/login")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

        let body = try #require(request.recoveredBody())
        let sent = try JSONDecoder().decode([String: String].self, from: body)
        #expect(sent == ["email": MockAuthService.validEmail, "password": MockAuthService.validPassword])
    }

    @Test("a description of the credentials payload redacts the password")
    func credentialsAreRedactedWhenInterpolated() {
        let payload = APIAuthService.CredentialsPayload(email: "adaeze@nutm.edu.ng", password: "hunter2")

        #expect("\(payload)".contains("hunter2") == false)
        #expect("\(payload)".contains("adaeze@nutm.edu.ng"))
    }

    @Test("a 200 decodes the session, its profile and its refresh window")
    func decodesSuccessfulSession() async throws {
        let sut = makeSUT()

        let session = try await sut.service.login(
            email: MockAuthService.validEmail,
            password: MockAuthService.validPassword
        )

        #expect(session.accessToken == "ajo_sess_25f7ffbb8a4255cbf69ef266f0ee6e03")
        #expect(session.user?.displayName == "Adaeze Okonkwo")
        #expect(session.user?.email == MockAuthService.validEmail)
        #expect(session.refreshToken == "ajo_refr_4aaa93308073977788240d6d657e1b35")
        #expect(session.isExpired == false)
    }

    @Test("a 401 surfaces the server's own sentence")
    func unauthorizedUsesServerMessage() async {
        let sut = makeSUT(statusCode: 401, body: Self.unauthorizedJSON)

        let error = await loginError(from: sut.service)

        #expect(error == .invalidCredentials(message: "That email and password don\u{2019}t match."))
        #expect(error?.errorDescription == "That email and password don\u{2019}t match.")
    }

    @Test("a 401 with an unreadable body falls back to generic copy")
    func unauthorizedWithoutEnvelopeFallsBack() async {
        let sut = makeSUT(statusCode: 401, body: "<html>gateway</html>")

        let error = await loginError(from: sut.service)

        #expect(error == .invalidCredentials(message: "Incorrect email or password. Please try again."))
    }

    @Test("a 422 becomes per-field issues")
    func validationFailureBecomesFieldIssues() async {
        let sut = makeSUT(statusCode: 422, body: Self.validationJSON)

        let error = await loginError(from: sut.service)

        #expect(error == .validation(fieldIssues: [
            "email": "is not a valid email address",
            "password": "is required",
        ]))
    }

    @Test("a 422 with no usable details still explains itself")
    func validationWithoutDetailsStillReports() async {
        let sut = makeSUT(
            statusCode: 422,
            body: #"{"code":"validation_failed","message":"One or more fields are invalid."}"#
        )

        let error = await loginError(from: sut.service)

        #expect(error == .validation(fieldIssues: [:]))
        #expect(error?.errorDescription?.contains("check the highlighted fields") == true)
    }

    @Test("a 429 reports how long to wait, from Retry-After")
    func rateLimitUsesRetryAfterHeader() async {
        let sut = makeSUT(
            statusCode: 429,
            body: #"{"code":"rate_limited","message":"Too many attempts."}"#,
            headers: ["Retry-After": "42"]
        )

        let error = await loginError(from: sut.service)

        #expect(error == .rateLimited(retryAfter: 42))
        #expect(error?.errorDescription?.contains("42 seconds") == true)
    }

    @Test("a 429 without Retry-After still explains itself")
    func rateLimitWithoutHeader() async {
        let sut = makeSUT(statusCode: 429, body: #"{"code":"rate_limited","message":"Slow down."}"#)

        let error = await loginError(from: sut.service)

        #expect(error == .rateLimited(retryAfter: nil))
        #expect(error?.errorDescription?.contains("wait a moment") == true)
    }

    @Test("a 5xx is reported as the server's problem", arguments: [500, 503])
    func serverErrorsAreMapped(statusCode: Int) async {
        let sut = makeSUT(statusCode: statusCode, body: "")

        let error = await loginError(from: sut.service)

        #expect(error == .serverError(statusCode: statusCode))
        #expect(error?.errorDescription?.contains("server is having trouble") == true)
    }

    @Test("an unexplained status does not claim the credentials were wrong")
    func unexpectedStatusIsNotCredentialFailure() async {
        let sut = makeSUT(statusCode: 404, body: #"{"code":"not_found","message":"No such endpoint."}"#)

        let error = await loginError(from: sut.service)

        #expect(error == .serverError(statusCode: 404))
        #expect(error?.errorDescription?.contains("Incorrect email") == false)
    }

    @Test("a 200 whose body is not a session is a decoding failure")
    func successWithUnusableBodyFails() async {
        let sut = makeSUT(body: #"{"hello":"world"}"#)

        let error = await loginError(from: sut.service)

        #expect(error == .decodingFailed)
    }

    @Test("a dropped connection is reported as a network problem")
    func transportFailureMapsToNetworkUnavailable() async {
        let sut = makeSUT(failingWith: URLError(.notConnectedToInternet))

        let error = await loginError(from: sut.service)

        #expect(error == .networkUnavailable)
    }

    @Test("an unrelated transport failure stays generic")
    func unrelatedTransportFailureIsGeneric() async {
        let sut = makeSUT(failingWith: URLError(.badServerResponse))

        let error = await loginError(from: sut.service)

        #expect(error == .unknown)
    }

    @Test("revokeSession deletes the session behind a bearer token")
    func revokeSessionSendsBearerDelete() async {
        let sut = makeSUT(statusCode: 204, body: "")

        await sut.service.revokeSession(AuthToken(accessToken: "ajo_sess_abc"))

        let request = sut.recorder.lastRequest
        #expect(request?.httpMethod == "DELETE")
        #expect(request?.url?.absoluteString == "\(Self.baseURL.absoluteString)/auth/session")
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer ajo_sess_abc")
    }

    @Test("a failed revocation is swallowed so logging out still works")
    func revokeSessionNeverThrows() async {
        let sut = makeSUT(statusCode: 500, body: "")

        await sut.service.revokeSession(AuthToken(accessToken: "ajo_sess_abc"))

        #expect(sut.recorder.lastRequest != nil)
    }
}