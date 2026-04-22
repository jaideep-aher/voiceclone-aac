import SwiftUI

struct RootFlowView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            switch auth.route {
            case .launching:
                ZStack {
                    Color.vcBackground.ignoresSafeArea()
                    ProgressView("Starting…")
                        .accessibilityLabel("Loading")
                }
            case .welcome:
                WelcomeView(
                    onGetStarted: { auth.beginSignUp() },
                    onHaveAccount: { auth.beginSignIn() }
                )
            case .auth(let isSignUp):
                SignUpView(isSignUp: isSignUp)
                    .environmentObject(auth)
            case .voiceSetup:
                VoiceSetupView()
                    .environmentObject(auth)
            case .home:
                HomeView()
                    .environmentObject(auth)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiUnauthorized)) { _ in
            auth.handleUnauthorized()
        }
    }
}
