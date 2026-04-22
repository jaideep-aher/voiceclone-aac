import SwiftUI

struct PhraseCard: View {
    let phrase: Phrase
    var highContrast: Bool
    var cacheCaption: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(highContrast ? .primary : .vcPrimary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(phrase.text)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(cacheCaption)
                        .font(.caption2)
                        .foregroundStyle(cacheCaption.contains("Cached") ? .green : .secondary)
                }
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.vcAccentTeal)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(highContrast ? Color.black.opacity(0.08) : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(highContrast ? Color.primary : Color.clear, lineWidth: highContrast ? 2 : 0)
            )
            .shadow(color: highContrast ? .clear : .vcCardShadow, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Speak phrase: \(phrase.text). \(cacheCaption)")
        .accessibilityHint("Double tap to speak this phrase")
        .frame(minHeight: 44)
    }
}
