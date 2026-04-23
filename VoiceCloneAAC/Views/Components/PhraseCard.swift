import SwiftUI

struct PhraseCard: View {
    let phrase: Phrase
    var highContrast: Bool
    var cacheCaption: String
    var action: () -> Void

    var body: some View {
        let bubbleTint: Color = highContrast ? .primary : .vcPrimary
        let captionTint: Color = cacheCaption.contains("Cached") ? .green : .secondary
        let cardFill: Color = highContrast ? Color.black.opacity(0.08) : .white
        let strokeColor: Color = highContrast ? .primary : .clear
        let strokeWidth: CGFloat = highContrast ? 2 : 0
        let shadowColor: Color = highContrast ? .clear : .vcCardShadow

        return Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(bubbleTint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(phrase.text)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(cacheCaption)
                        .font(.caption2)
                        .foregroundStyle(captionTint)
                }
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(Color.vcAccentTeal)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Speak phrase: \(phrase.text). \(cacheCaption)")
        .accessibilityHint("Double tap to speak this phrase")
        .frame(minHeight: 44)
    }
}
