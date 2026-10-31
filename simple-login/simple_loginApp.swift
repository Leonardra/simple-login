import SwiftUI

@main
struct simple_loginApp: App {
    @State private var viewModel = LoginViewModel(authService: AppConfiguration.authService)

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
    }
}
