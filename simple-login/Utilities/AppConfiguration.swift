import Foundation

enum AppConfiguration {
    static let defaultAuthBaseURL = "https://nutmtrainingbackend.dataalcomms.com/v1"

    static var authBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["AUTH_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: defaultAuthBaseURL)!
    }

    static var authService: any AuthServiceProtocol {
        #if DEBUG
//        if ProcessInfo.processInfo.environment["USE_MOCK_AUTH"] == "1" {
            return MockAuthService()
//        }
        #endif
//        return APIAuthService(baseURL: authBaseURL)
    }
}
