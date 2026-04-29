import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var isSignUp: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isBusy = false
    @State private var localError: String?

    init(isSignUp: Bool) {
        _isSignUp = State(initialValue: isSignUp)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(isSignUp ? "Create your account" : "Welcome back")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.vcPrimary)
                    .accessibilityAddTraits(.isHeader)

                // Sign in with Apple is re-enabled when enrolled in
                // the Apple Developer Program ($99/yr). Personal Team
                // accounts do not support this capability.

                Group {
                    if isSignUp {
                        TextField("Display name", text: $displayName)
                            .textContentType(.name)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                            .accessibilityLabel("Display name")
                    }

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        .accessibilityLabel("Email")

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        .accessibilityLabel("Password")
                }

                if let localError {
                    Text(localError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityLabel(localError)
                }

                Button(action: { Task { await submit() } }) {
                    HStack {
                        if isBusy { ProgressView().tint(.white) }
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.title3.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(.vcPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .disabled(isBusy || email.isEmpty || password.isEmpty || (isSignUp && displayName.isEmpty))
                .accessibilityLabel(isSignUp ? "Create account" : "Sign in")

                Button(action: { isSignUp.toggle(); localError = nil }) {
                    Text(isSignUp ? "Already have an account? Sign in" : "New here? Create an account")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.vcPrimary)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(isSignUp ? "Switch to sign in" : "Switch to create account")

                Button("Back") { auth.backToWelcome() }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Back to welcome")
            }
            .padding(24)
        }
        .background(Color.vcBackground.ignoresSafeArea())
    }

    private func submit() async {
        isBusy = true
        localError = nil
        defer { isBusy = false }
        do {
            if isSignUp {
                let session = try await APIService.shared.signUp(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespaces)
                )
                try await auth.handleSession(session)
            } else {
                let session = try await APIService.shared.login(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
                try await auth.handleSession(session)
            }
        } catch {
            localError = error.localizedDescription
        }
    }
}
