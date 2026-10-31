import Foundation

struct MockAuthService: AuthServiceProtocol {
    static let validEmail = "adaeze.okonkwo@nutm.edu.ng"
    static let validPassword = "password"
    static let displayName = "Adaeze Okonkwo"

    private static let sessionLifetime: TimeInterval = 7 * 24 * 3_600
    private static let refreshLifetime: TimeInterval = 30 * 24 * 3_600

    var delay: Duration = .milliseconds(1_500)

    func login(email: String, password: String) async throws -> AuthToken {
        try await Task.sleep(for: delay)

        guard email.caseInsensitiveCompare(Self.validEmail) == .orderedSame,
              password == Self.validPassword
        else {
            throw AuthError.genericInvalidCredentials
        }

        return AuthToken(
            accessToken: "mock-session-token",
            expiresAt: Date().addingTimeInterval(Self.sessionLifetime),
            refreshToken: "mock-refresh-token",
            refreshExpiresAt: Date().addingTimeInterval(Self.refreshLifetime),
            user: AuthUser(
                id: "3b241101-e2bb-4255-8caf-4136c566a962",
                displayName: Self.displayName,
                email: Self.validEmail,
                avatarURL: nil
            )
        )
    }
}