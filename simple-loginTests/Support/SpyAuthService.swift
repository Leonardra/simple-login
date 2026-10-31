import Foundation

@testable import simple_login

@MainActor
final class SpyAuthService: AuthServiceProtocol {
    var loginResult: Result<AuthToken, any Error> = .success(
        AuthToken(
            accessToken: "spy-session-token",
            user: AuthUser(
                id: "3b241101-e2bb-4255-8caf-4136c566a962",
                displayName: "Spy User",
                email: "spy@example.com",
                avatarURL: nil
            )
        )
    )

    private(set) var revokedSessions: [AuthToken] = []

    var revokedTokens: [String] { revokedSessions.map(\.accessToken) }

    private(set) var loginCallCount = 0

    var whenRevoking: (() -> Void)?

    func login(email: String, password: String) async throws -> AuthToken {
        loginCallCount += 1
        return try loginResult.get()
    }

    func revokeSession(_ session: AuthToken) async {
        whenRevoking?()
        revokedSessions.append(session)
    }
}