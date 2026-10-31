import Foundation

protocol AuthTokenStore: Sendable {
    func loadToken() -> String?
    func saveToken(_ token: String)
    func clearToken()
}

struct KeychainAuthTokenStore: AuthTokenStore {
    private let account = "accessToken"

    nonisolated init() {}

    func loadToken() -> String? {
        try? KeychainHelper.read(account: account)
    }

    func saveToken(_ token: String) {
        try? KeychainHelper.save(token, account: account)
    }

    func clearToken() {
        KeychainHelper.delete(account: account)
    }
}

final class InMemoryAuthTokenStore: AuthTokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func loadToken() -> String? {
        lock.withLock { token }
    }

    func saveToken(_ token: String) {
        lock.withLock { self.token = token }
    }

    func clearToken() {
        lock.withLock { token = nil }
    }
}