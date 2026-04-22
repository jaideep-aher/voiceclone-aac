import SwiftUI

struct RecentPhrasesView: View {
    let phrases: [Phrase]
    var highContrast: Bool
    var cacheCaption: (Phrase) -> String
    var onSpeak: (Phrase) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent")
                .font(.headline)
                .foregroundStyle(Color.vcPrimary)
                .accessibilityAddTraits(.isHeader)

            if phrases.isEmpty {
                Text("Speak something to build your recent list.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("No recent phrases yet")
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(phrases) { phrase in
                        PhraseCard(
                            phrase: phrase,
                            highContrast: highContrast,
                            cacheCaption: cacheCaption(phrase)
                        ) {
                            onSpeak(phrase)
                        }
                    }
                }
            }
        }
    }
}
