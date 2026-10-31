import Foundation
import Testing

@testable import simple_login

@Suite("AppConfiguration")
struct AppConfigurationTests {

    @Test("the default auth base URL is a valid URL with the documented /v1 path")
    func defaultBaseURLIsUsable() throws {
        let url = try #require(URL(string: AppConfiguration.defaultAuthBaseURL))

        #expect(url.scheme == "https")
        #expect(url.host() == "nutmtrainingbackend.dataalcomms.com")
        #expect(url.path() == "/v1")
    }

    @Test("appending the auth resource paths matches the endpoint's routes")
    func resourcePathsMatchTheContract() throws {
        let baseURL = try #require(URL(string: AppConfiguration.defaultAuthBaseURL))

        #expect(baseURL.appending(path: "auth/login").absoluteString.hasSuffix("/v1/auth/login"))
        #expect(baseURL.appending(path: "auth/session").absoluteString.hasSuffix("/v1/auth/session"))
    }

    @Test("the production service is the real API client, not the offline mock")
    func productionServiceIsTheAPIClient() {
        #if !DEBUG
        #expect(AppConfiguration.authService is APIAuthService)
        #endif
    }
}