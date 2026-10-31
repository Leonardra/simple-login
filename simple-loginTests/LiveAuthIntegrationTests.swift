import Foundation
import Testing

@testable import simple_login

@Suite(
    "Live endpoint integration",
    .serialized,
    .enabled(
        if: ProcessInfo.processInfo.environment["LIVE_AUTH_TESTS"] == "1",
        "set TEST_RUNNER_LIVE_AUTH_TESTS=1 to run against the deployed API"
    )
)
struct LiveAuthIntegrationTests {

    private static let baseURL = AppConfiguration.authBaseURL

    private var service: APIAuthService { APIAuthService(baseURL: Self.baseURL) }

    @Test("the deployed endpoint exchanges the documented demo credentials for a session")
    func liveLoginSucceeds() async throws {
        let token = try await service.login(
            email: MockAuthService.validEmail,
            password: MockAuthService.validPassword
        )

        #expect(!token.accessToken.isEmpty)
        #expect(token.expiresAt != nil, "the live response must carry a usable expiry")
        #expect(token.isExpired == false, "a fresh session must not arrive already expired")

        let user = try #require(token.user, "the live response must carry the profile Home greets with")
        #expect(user.email == MockAuthService.validEmail)
        #expect(!user.displayName.isEmpty)

        #expect(token.refreshToken != nil)

        await service.revokeSession(token)
    }

    @Test("a real rejection surfaces the server's own sentence, not our fallback")
    func liveLoginRejectionUsesServerCopy() async {
        do {
            _ = try await service.login(
                email: MockAuthService.validEmail,
                password: "definitely-not-the-password"
            )
            Issue.record("expected the live endpoint to reject a wrong password")
        } catch let error as AuthError {
            guard case .invalidCredentials(let message) = error else {
                Issue.record("expected .invalidCredentials, got \(error)")
                return
            }
            #expect(message != AuthError.genericInvalidCredentials.errorDescription)
            #expect(!message.isEmpty)
        } catch {
            Issue.record("expected an AuthError, got \(error)")
        }
    }

    @Test("the session survives a round trip through the keychain")
    func liveTokenRoundTripsThroughStorage() async throws {
        let token = try await service.login(
            email: MockAuthService.validEmail,
            password: MockAuthService.validPassword
        )
        defer { Task { await service.revokeSession(token) } }

        let store = KeychainAuthTokenStore()
        let original = store.loadToken()
        defer { restore(original, into: store) }

        store.saveToken(token.accessToken)

        #expect(store.loadToken() == token.accessToken)
    }

    private func restore(_ token: String?, into store: KeychainAuthTokenStore) {
        if let token {
            store.saveToken(token)
        } else {
            store.clearToken()
        }
    }
}