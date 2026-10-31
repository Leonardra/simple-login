import Foundation

struct AuthToken: Decodable, Equatable, Sendable {
    let accessToken: String

    let expiresAt: Date?

    let refreshToken: String?

    let refreshExpiresAt: Date?

    let user: AuthUser?

    init(
        accessToken: String,
        expiresAt: Date? = nil,
        refreshToken: String? = nil,
        refreshExpiresAt: Date? = nil,
        user: AuthUser? = nil
    ) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.refreshToken = refreshToken
        self.refreshExpiresAt = refreshExpiresAt
        self.user = user
    }

    init(accessToken: String, expiresIn: TimeInterval) {
        self.init(accessToken: accessToken, expiresAt: Date().addingTimeInterval(expiresIn))
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case expiresAt
        case refreshToken
        case refreshExpiresAt
        case user

        case accessTokenSnake = "access_token"
        case expiresAtSnake = "expires_at"
        case expiresIn = "expires_in"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let token = try container.decodeIfPresent(String.self, forKey: .token) {
            self.accessToken = token
        } else {
            self.accessToken = try container.decode(String.self, forKey: .accessTokenSnake)
        }

        self.user = try container.decodeIfPresent(AuthUser.self, forKey: .user)
        self.refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        self.refreshExpiresAt = try container.decodeIfPresent(Date.self, forKey: .refreshExpiresAt)

        if let expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt) {
            self.expiresAt = expiresAt
        } else if let expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAtSnake) {
            self.expiresAt = expiresAt
        } else if let expiresIn = try container.decodeIfPresent(TimeInterval.self, forKey: .expiresIn) {
            self.expiresAt = Date().addingTimeInterval(expiresIn)
        } else {
            self.expiresAt = nil
        }
    }

    var headerValue: String { "Bearer \(accessToken)" }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date()
    }
}
