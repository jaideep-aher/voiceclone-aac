import SwiftUI

struct RecentPhrasesView: View {
    let phrases: [Phrase]
    var sectionTitle: String = "Recent"
    var highContrast: Bool
    var cacheCaption: (Phrase) -> String
    var onSpeak: (Phrase) -> Void
    var onDelete: ((Phrase) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sectionTitle)
                .font(.headline)
                .foregroundStyle(Color.vcPrimary)
                .accessibilityAddTraits(.isHeader)

            if phrases.isEmpty {
                Text(sectionTitle == "Results" ? "No matching phrases found." : "Speak something to build your recent list.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(sectionTitle == "Results" ? "No results" : "No recent phrases yet")
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
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            if let onDelete {
                                Button(role: .destructive) {
                                    onDelete(phrase)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
