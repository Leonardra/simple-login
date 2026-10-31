import Foundation
import Testing

@testable import simple_login

@Suite("AuthError mapping")
struct AuthErrorMappingTests {

    private func envelope(_ json: String) -> APIError? {
        APIError.decode(from: Data(json.utf8))
    }

    @Test("the envelope decodes code, message and per-field details")
    func decodesEnvelope() throws {
        let body = try #require(envelope(#"""
        {"code":"validation_failed","message":"One or more fields are invalid.","details":[{"field":"email","issue":"is not a valid email address"},{"field":"password","issue":"is required"}]}
        """#))

        #expect(body.code == "validation_failed")
        #expect(body.message == "One or more fields are invalid.")
        #expect(body.details?.count == 2)
        #expect(body.fieldIssues == [
            "email": "is not a valid email address",
            "password": "is required",
        ])
    }

    @Test("an envelope without details yields no field issues")
    func envelopeWithoutDetails() throws {
        let body = try #require(envelope(#"{"code":"unauthorized","message":"Nope."}"#))

        #expect(body.details == nil)
        #expect(body.fieldIssues.isEmpty)
    }

    @Test("a repeated field keeps its first issue instead of trapping")
    func duplicateFieldDoesNotCrash() throws {
        let body = try #require(envelope(#"""
        {"code":"validation_failed","message":"Invalid.","details":[{"field":"email","issue":"first"},{"field":"email","issue":"second"}]}
        """#))

        #expect(body.fieldIssues == ["email": "first"])
    }

    @Test("a body that is not an envelope decodes to nil rather than throwing")
    func nonJSONBodyIsNotAnEnvelope() {
        #expect(APIError.decode(from: Data("<html>502 Bad Gateway</html>".utf8)) == nil)
        #expect(APIError.decode(from: Data()) == nil)
    }

    @Test("a validation failure keeps only the part the UI can render")
    func validationMapping() {
        let error = AuthError.fromAPIError(
            envelope(#"{"code":"validation_failed","message":"One or more fields are invalid.","details":[{"field":"password","issue":"is required"}]}"#),
            statusCode: 422
        )

        #expect(error == .validation(fieldIssues: ["password": "is required"]))
    }

    @Test("status codes alone still classify when the body says nothing")
    func statusCodeFallback() {
        #expect(AuthError.fromAPIError(nil, statusCode: 401) == .invalidCredentials(message: "Incorrect email or password. Please try again."))
        #expect(AuthError.fromAPIError(nil, statusCode: 403) == .invalidCredentials(message: "Incorrect email or password. Please try again."))
        #expect(AuthError.fromAPIError(nil, statusCode: 429) == .rateLimited(retryAfter: nil))
        #expect(AuthError.fromAPIError(nil, statusCode: 500) == .serverError(statusCode: 500))
        #expect(AuthError.fromAPIError(nil, statusCode: 404) == .serverError(statusCode: 404))
    }

    @Test("an unknown code falls back to the status, not to a guess")
    func unknownCodeUsesStatus() {
        let error = AuthError.fromAPIError(
            envelope(#"{"code":"teapot","message":"I'm a teapot."}"#),
            statusCode: 418
        )

        #expect(error == .serverError(statusCode: 418))
    }

    @Test("from(error) sanitises anything the service layer throws")
    func normalisationBackstop() {
        #expect(AuthError.from(URLError(.timedOut)) == .networkUnavailable)
        #expect(AuthError.from(URLError(.notConnectedToInternet)) == .networkUnavailable)
        #expect(AuthError.from(URLError(.badServerResponse)) == .unknown)
        #expect(AuthError.from(AuthError.validation(fieldIssues: [:])) == .validation(fieldIssues: [:]))
        #expect(AuthError.from(APIError(code: "unauthorized", message: "Nope.", details: nil))
            == .invalidCredentials(message: "Nope."))
    }

    @Test("every error renders a sentence, and none of them leak developer detail")
    func everyErrorHasUserFacingCopy() throws {
        let errors: [AuthError] = [
            .invalidCredentials(message: "That email and password don\u{2019}t match."),
            .validation(fieldIssues: [:]),
            .rateLimited(retryAfter: 30),
            .rateLimited(retryAfter: nil),
            .networkUnavailable,
            .serverError(statusCode: 500),
            .serverError(statusCode: 404),
            .decodingFailed,
            .unknown,
        ]

        for error in errors {
            let message = try #require(error.errorDescription)
            #expect(!message.isEmpty)
            #expect(message.contains("Error Domain") == false)
            #expect(message.contains("NSURLError") == false)
        }
    }

    @Test("a Retry-After value is rounded up so the retry is not too early")
    func rateLimitRoundsUp() {
        let error = AuthError.rateLimited(retryAfter: 4.2)

        #expect(error.errorDescription?.contains("5 seconds") == true)
    }
}