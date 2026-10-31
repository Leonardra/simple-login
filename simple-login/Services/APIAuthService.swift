import Foundation

struct APIAuthService: AuthServiceProtocol {
    private let baseURL: URL
    private let session: URLSession

    private static let timeout: TimeInterval = 30

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func login(email: String, password: String) async throws -> AuthToken {
        var request = URLRequest(url: baseURL.appending(path: "auth/login"))
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let payload = CredentialsPayload(email: email, password: password)
        guard let body = try? JSONEncoder().encode(payload) else {
            throw AuthError.unknown
        }
        request.httpBody = body

        let (data, response) = try await perform(request)
        try Self.validate(data: data, response: response)

        do {
            return try AuthToken.decoder().decode(AuthToken.self, from: data)
        } catch {
            throw AuthError.decodingFailed
        }
    }

    func revokeSession(_ session: AuthToken) async {
        var request = URLRequest(url: baseURL.appending(path: "auth/session"))
        request.httpMethod = "DELETE"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(session.headerValue, forHTTPHeaderField: "Authorization")

        _ = try? await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dataNotAllowed:
                throw AuthError.networkUnavailable
            default:
                throw AuthError.unknown
            }
        } catch {
            throw AuthError.unknown
        }
    }

    private static func validate(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.unknown
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw AuthError.fromAPIError(
                APIError.decode(from: data),
                statusCode: httpResponse.statusCode,
                retryAfter: retryAfter(from: httpResponse)
            )
        }
    }

    private static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return TimeInterval(raw.trimmingCharacters(in: .whitespaces))
    }

    struct CredentialsPayload: Encodable, CustomStringConvertible {
        let email: String
        let password: String

        var description: String { "CredentialsPayload(email: \(email), password: <redacted>)" }
    }
}