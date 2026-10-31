import Foundation

@testable import simple_login

struct StubAuthService: AuthServiceProtocol {
    let result: Result<AuthToken, any Error>

    func login(email: String, password: String) async throws -> AuthToken {
        try result.get()
    }
}
