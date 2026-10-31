import Foundation

struct AuthUser: Decodable, Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let email: String

    let avatarURL: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case email
        case avatarURL = "avatarUrl"
    }
}