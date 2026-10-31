import Foundation

enum AuthError: Error, LocalizedError, Equatable {
    case invalidCredentials(message: String)

    case validation(fieldIssues: [String: String])

    case rateLimited(retryAfter: TimeInterval?)

    case networkUnavailable

    case serverError(statusCode: Int)

    case decodingFailed

    case unknown

    static let genericInvalidCredentials = AuthError.invalidCredentials(
        message: "Incorrect email or password. Please try again."
    )

    var errorDescription: String? {
        switch self {
        case .invalidCredentials(let message):
            message

        case .validation:
            "Please check the highlighted fields and try again."

        case .rateLimited(let retryAfter):
            if let retryAfter, retryAfter > 0 {
                "Too many attempts. Please try again in \(Int(retryAfter.rounded(.up))) seconds."
            } else {
                "Too many attempts. Please wait a moment and try again."
            }

        case .networkUnavailable:
            "No internet connection. Check your network and try again."

        case .serverError(let statusCode):
            if (500...599).contains(statusCode) {
                "The server is having trouble right now. Please try again later."
            } else {
                "We couldn't complete your request. Please try again."
            }

        case .decodingFailed:
            "We received an unexpected response from the server. Please try again."

        case .unknown:
            "Something went wrong. Please try again."
        }
    }

    static func fromAPIError(
        _ body: APIError?,
        statusCode: Int,
        retryAfter: TimeInterval? = nil
    ) -> AuthError {
        switch (body?.code, statusCode) {
        case ("validation_failed", _):
            .validation(fieldIssues: body?.fieldIssues ?? [:])

        case ("unauthorized", _), ("invalid_credentials", _), ("unauthenticated", _),
             (_, 401), (_, 403):
            .invalidCredentials(message: body?.message ?? genericMessage)

        case ("rate_limited", _), (_, 429):
            .rateLimited(retryAfter: retryAfter)

        case (_, 500...599):
            .serverError(statusCode: statusCode)

        case (_, let status):
            .serverError(statusCode: status)
        }
    }

    private static let genericMessage = "Incorrect email or password. Please try again."

    static func from(_ error: any Error) -> AuthError {
        switch error {
        case let authError as AuthError:
            authError
        case let apiError as APIError:
            .fromAPIError(apiError, statusCode: 0)
        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dataNotAllowed:
                .networkUnavailable
            default:
                .unknown
            }
        case is DecodingError:
            .decodingFailed
        default:
            .unknown
        }
    }
}