import SwiftUI

struct HomeView: View {
    let name: String
    let email: String
    let onLogOut: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(greeting)
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            if !email.isEmpty {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button("Log Out", action: onLogOut)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 16)
                .accessibilityLabel("Log out")
                .accessibilityHint("Clears your saved session and returns to the login screen.")
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var greeting: String {
        name.isEmpty ? "Welcome" : "Welcome, \(name)"
    }
}

#Preview("Just signed in") {
    HomeView(name: MockAuthService.displayName, email: MockAuthService.validEmail) {}
}

#Preview("Restored session (no profile in memory)") {
    HomeView(name: "", email: "") {}
}