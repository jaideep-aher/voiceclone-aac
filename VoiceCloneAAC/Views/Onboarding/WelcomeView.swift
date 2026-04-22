import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void
    var onHaveAccount: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)

            Image(systemName: "waveform.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.vcPrimary, Color.vcAccentTeal.opacity(0.35))
                .font(.system(size: 96))
                .accessibilityLabel("VoiceClone AAC app icon")

            VStack(spacing: 12) {
                Text("Your Voice, Preserved.")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.vcPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text("Clone your voice with a 15-second recording. Speak using your own voice, forever.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Spacer()

            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 56)
            }
            .buttonStyle(.borderedProminent)
            .tint(.vcPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityLabel("Get started")

            Button(action: onHaveAccount) {
                Text("I already have an account")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.vcPrimary)
            }
            .accessibilityLabel("I already have an account")

            Spacer(minLength: 16)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.vcBackground.ignoresSafeArea())
    }
}
