import Foundation

protocol AuthServiceProtocol: Sendable {
    func login(email: String, password: String) async throws -> AuthToken

    func revokeSession(_ session: AuthToken) async
}

extension AuthServiceProtocol {
    func revokeSession(_ session: AuthToken) async {}
}