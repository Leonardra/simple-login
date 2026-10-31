import Foundation

@testable import simple_login

@MainActor
final class SuspendedAuthService: AuthServiceProtocol {
    private(set) var receivedEmail: String?
    private(set) var requestCount = 0

    var hasReceivedRequest: Bool { requestCount > 0 }

    private var continuation: CheckedContinuation<AuthToken, any Error>?

    func login(email: String, password: String) async throws -> AuthToken {
        requestCount += 1
        receivedEmail = email

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume(returning token: AuthToken) {
        continuation?.resume(returning: token)
        continuation = nil
    }

    func resume(throwing error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
