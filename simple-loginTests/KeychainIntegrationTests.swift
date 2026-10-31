import Testing

@testable import simple_login

@Suite("KeychainHelper", .serialized)
struct KeychainIntegrationTests {
    private let service = "simple-login.tests"
    private let account = "round-trip"

    @Test("save, overwrite, read and delete round-trip through the real keychain")
    func roundTrip() throws {
        defer { KeychainHelper.delete(account: account, service: service) }

        #expect(try KeychainHelper.read(account: account, service: service) == nil)

        try KeychainHelper.save("token-1", account: account, service: service)
        #expect(try KeychainHelper.read(account: account, service: service) == "token-1")

        try KeychainHelper.save("token-2", account: account, service: service)
        #expect(try KeychainHelper.read(account: account, service: service) == "token-2")

        #expect(KeychainHelper.delete(account: account, service: service))
        #expect(try KeychainHelper.read(account: account, service: service) == nil)
    }

    @Test("deleting an item that was never written is not an error")
    func deletingMissingItemSucceeds() {
        #expect(KeychainHelper.delete(account: "never-written", service: service))
    }
}
