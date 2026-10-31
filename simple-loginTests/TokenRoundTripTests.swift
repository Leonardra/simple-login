import Foundation
import Testing

@testable import simple_login

@Suite("Token and store behaviour")
struct TokenRoundTripTests {

    @Test("the live session payload decodes into a token, an expiry and a profile")
    func decodesLiveSessionPayload() throws {
        let json = #"""
        {"token":"ajo_sess_25f7ffbb8a4255cbf69ef266f0ee6e03",
         "expiresAt":"2026-10-30T21:59:06Z",
         "user":{"id":"3b241101-e2bb-4255-8caf-4136c566a962",
                 "displayName":"Adaeze Okonkwo",
                 "email":"adaeze.okonkwo@nutm.edu.ng",
                 "avatarUrl":null,
                 "createdAt":"2026-08-13T04:37:46Z"},
         "refreshToken":"ajo_refr_4aaa93308073977788240d6d657e1b35",
         "refreshExpiresAt":"2026-11-22T21:59:06Z"}
        """#.data(using: .utf8)!

        let session = try AuthToken.decoder().decode(AuthToken.self, from: json)

        #expect(session.accessToken == "ajo_sess_25f7ffbb8a4255cbf69ef266f0ee6e03")
        #expect(session.expiresAt == ISO8601DateFormatter().date(from: "2026-10-30T21:59:06Z"))
        #expect(session.refreshToken == "ajo_refr_4aaa93308073977788240d6d657e1b35")
        #expect(session.user?.displayName == "Adaeze Okonkwo")
        #expect(session.user?.email == "adaeze.okonkwo@nutm.edu.ng")
        #expect(session.user?.avatarURL == nil)
        #expect(session.isExpired == false)
    }

    @Test("the bearer header is built from the token")
    func buildsBearerHeader() {
        let session = AuthToken(accessToken: "ajo_sess_abc")

        #expect(session.headerValue == "Bearer ajo_sess_abc")
    }

    @Test("a legacy snake_case payload still decodes")
    func decodesLegacySnakeCasePayload() throws {
        let json = #"{"access_token":"abc123","expires_at":"1970-01-01T00:00:00Z"}"#
            .data(using: .utf8)!

        let session = try AuthToken.decoder().decode(AuthToken.self, from: json)

        #expect(session.accessToken == "abc123")
        #expect(session.expiresAt == Date(timeIntervalSince1970: 0))
    }

    @Test("a legacy expires_in count becomes an absolute expiry date")
    func decodesRelativeExpiry() throws {
        let json = #"{"access_token":"abc123","expires_in":3600}"#.data(using: .utf8)!

        let session = try AuthToken.decoder().decode(AuthToken.self, from: json)

        #expect(session.accessToken == "abc123")
        let expiresAt = try #require(session.expiresAt)
        #expect(abs(expiresAt.timeIntervalSinceNow - 3600) < 5)
        #expect(session.isExpired == false)
    }

    @Test("an ISO-8601 expiresAt is taken literally")
    func decodesAbsoluteExpiry() throws {
        let json = #"{"token":"abc123","expiresAt":"1970-01-01T00:00:00Z"}"#.data(using: .utf8)!

        let session = try AuthToken.decoder().decode(AuthToken.self, from: json)

        #expect(session.expiresAt == Date(timeIntervalSince1970: 0))
        #expect(session.isExpired)
    }

    @Test("a numeric expiresAt fails loudly instead of being misread as a 2001 date")
    func numericAbsoluteExpiryIsRejected() {
        let json = #"{"token":"abc123","expiresAt":0}"#.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try AuthToken.decoder().decode(AuthToken.self, from: json)
        }
    }

    @Test("a payload without expiry information is treated as usable")
    func missingExpiryIsNotExpired() throws {
        let json = #"{"token":"abc123"}"#.data(using: .utf8)!

        let session = try AuthToken.decoder().decode(AuthToken.self, from: json)

        #expect(session.expiresAt == nil)
        #expect(session.isExpired == false)
    }

    @Test("a payload without a token fails to decode")
    func missingTokenThrows() {
        let json = #"{"expiresAt":"2026-10-30T21:59:06Z"}"#.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            try AuthToken.decoder().decode(AuthToken.self, from: json)
        }
    }

    @Test("the in-memory store saves, loads and clears")
    func inMemoryStoreRoundTrip() {
        let store = InMemoryAuthTokenStore()

        #expect(store.loadToken() == nil)

        store.saveToken("token-1")
        #expect(store.loadToken() == "token-1")

        store.clearToken()
        #expect(store.loadToken() == nil)
    }
}
