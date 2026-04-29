import SwiftUI

struct RootFlowView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        Group {
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
            case .voiceSetup:
                VoiceSetupView()
                    .environmentObject(auth)
            case .home:
                HomeView()
                    .environmentObject(auth)
            }
        }
    }
}
