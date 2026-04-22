import AuthenticationServices
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

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .failure(let err):
                        localError = err.localizedDescription
                    case .success(let authorization):
                        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
                              let tokenData = cred.identityToken,
                              let idToken = String(data: tokenData, encoding: .utf8)
                        else {
                            localError = "Could not read Apple identity token."
                            return
                        }
                        Task { await signInApple(idToken: idToken) }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityLabel("Sign in with Apple")

                HStack {
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                    Text("or")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                }
                .accessibilityHidden(true)

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

    private func signInApple(idToken: String) async {
        isBusy = true
        localError = nil
        defer { isBusy = false }
        do {
            let session = try await APIService.shared.signInWithApple(idToken: idToken, nonce: nil)
            try await auth.handleSession(session)
        } catch {
            localError = error.localizedDescription
        }
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
