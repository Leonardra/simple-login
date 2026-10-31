import Foundation

enum LoginValidator {
    static let emailPattern = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/
        .ignoresCase()

    static let minimumPasswordLength = 8

    static func trimmedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidEmail(_ email: String) -> Bool {
        let normalized = trimmedEmail(email)
        return !normalized.isEmpty && normalized.wholeMatch(of: emailPattern) != nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }

    static func emailErrorMessage(for email: String) -> String? {
        let normalized = trimmedEmail(email)
        if normalized.isEmpty {
            return "Enter your email address."
        }
        return isValidEmail(normalized) ? nil : "Enter a valid email address."
    }

    static func passwordErrorMessage(for password: String) -> String? {
        if password.isEmpty {
            return "Enter your password."
        }
        guard isValidPassword(password) else {
            return "Password must be at least \(minimumPasswordLength) characters."
        }
        return nil
    }
}