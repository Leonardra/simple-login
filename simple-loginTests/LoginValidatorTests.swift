import Testing

@testable import simple_login

@Suite("LoginValidator")
struct LoginValidatorTests {

    @Test(
        "recognised email shapes",
        arguments: [
            "test@example.com",
            "a.b+tag@sub.example.co.uk",
            "  padded@example.com  ",
            "MIXED.Case@Example.COM",
        ]
    )
    func accepts(email: String) {
        #expect(LoginValidator.isValidEmail(email))
    }

    @Test(
        "rejected email shapes",
        arguments: [
            "",
            "   ",
            "not-an-email",
            "missing@domain",
            "@example.com",
            "user@.com",
            "two@@example.com",
            "user@exa mple.com",
        ]
    )
    func rejects(email: String) {
        #expect(LoginValidator.isValidEmail(email) == false)
    }

    @Test("passwords need at least 8 characters")
    func passwordLengthBoundary() {
        #expect(LoginValidator.isValidPassword(String(repeating: "a", count: 7)) == false)
        #expect(LoginValidator.isValidPassword(String(repeating: "a", count: 8)))
    }

    @Test("the boundary rule matches the message shown to the user")
    func messageQuotesTheRule() {
        let short = String(repeating: "a", count: LoginValidator.minimumPasswordLength - 1)
        #expect(
            LoginValidator.passwordErrorMessage(for: short)
                == "Password must be at least \(LoginValidator.minimumPasswordLength) characters."
        )
    }

    @Test("messages distinguish an empty field from an invalid one")
    func emptyVersusInvalidMessages() {
        #expect(LoginValidator.emailErrorMessage(for: "") == "Enter your email address.")
        #expect(LoginValidator.emailErrorMessage(for: "nope") == "Enter a valid email address.")
        #expect(LoginValidator.emailErrorMessage(for: "test@example.com") == nil)
        #expect(LoginValidator.passwordErrorMessage(for: "") == "Enter your password.")
        #expect(LoginValidator.passwordErrorMessage(for: "Password123") == nil)
    }
}
