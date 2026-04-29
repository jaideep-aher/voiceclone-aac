import SwiftUI

struct RootFlowView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
            // Show a clear setup screen if the backend URL hasn't been configured yet.
            if Constants.apiURLIsPlaceholder {
                BackendNotConfiguredView()
            } else {
                switch auth.route {
                case .launching:
                    ZStack {
                        Color.vcBackground.ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(Color.vcPrimary)
                            ProgressView("Starting…")
                        }
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiUnauthorized)) { _ in
            auth.handleUnauthorized()
        }
    }
}

// Shown when Constants.swift still has the placeholder Railway URL.
private struct BackendNotConfiguredView: View {
    var body: some View {
        ZStack {
            Color.vcBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)

                Text("Backend Not Connected")
                    .font(.title2.bold())
                    .foregroundStyle(Color.vcPrimary)

                Text("The app needs a backend URL to work.\n\nOpen Constants.swift and replace\n\"YOUR_RAILWAY_URL\" with your\nRailway deployment URL.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
}
