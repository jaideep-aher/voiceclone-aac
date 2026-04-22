import SwiftUI

struct SpeakButton: View {
    let title: String
    let isLoading: Bool
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.vcAccentTeal)
                    .shadow(color: .vcCardShadow, radius: 4, x: 0, y: 2)
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel("Synthesizing speech")
                } else {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .disabled(isLoading || isDisabled)
        .accessibilityLabel(title)
        .accessibilityHint("Generates speech from your text using your cloned voice")
        .frame(minHeight: 44)
    }
}
