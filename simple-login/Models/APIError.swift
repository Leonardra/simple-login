import Foundation

struct APIError: Error, Decodable, Equatable, Sendable {
    let code: String

    let message: String

    let details: [Detail]?

    struct Detail: Decodable, Equatable, Sendable {
        let field: String
        let issue: String
    }

    var fieldIssues: [String: String] {
        guard let details else { return [:] }
        return Dictionary(details.map { ($0.field, $0.issue) }) { first, _ in first }
    }

    static func decode(from data: Data) -> APIError? {
        try? JSONDecoder().decode(APIError.self, from: data)
    }
}