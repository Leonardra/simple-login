import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .imageScale(.medium)
                .accessibilityHidden(true)

            Text(message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error message")
        }
        .padding(12)
        .foregroundStyle(Color.red)
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

#Preview {
    ErrorBanner(message: AuthError.genericInvalidCredentials.errorDescription ?? "") {}
        .padding()
}

#Preview("Server-side validation") {
    ErrorBanner(message: AuthError.validation(fieldIssues: [:]).errorDescription ?? "") {}
        .padding()
}