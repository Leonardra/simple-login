import SwiftUI

struct RootView: View {
    let viewModel: LoginViewModel

    var body: some View {
        Group {
            if viewModel.isAuthenticated {
                HomeView(
                    name: viewModel.signedInName,
                    email: viewModel.signedInEmail,
                    onLogOut: { Task { await viewModel.logOut() } }
                )
                .transition(.opacity)
            } else {
                LoginView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isAuthenticated)
    }
}

#Preview("Logged out") {
    RootView(viewModel: LoginViewModel(
        authService: MockAuthService(delay: .milliseconds(200)),
        tokenStore: InMemoryAuthTokenStore()
    ))
}

#Preview("Restored session") {
    RootView(viewModel: LoginViewModel(
        authService: MockAuthService(delay: .milliseconds(200)),
        tokenStore: InMemoryAuthTokenStore(token: "restored-token")
    ))
}