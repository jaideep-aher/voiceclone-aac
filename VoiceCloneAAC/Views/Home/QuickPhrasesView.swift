import SwiftUI

struct QuickPhrasesView: View {
    let phrases: [String]
    var highContrast: Bool
    var isPhraseCached: (String) -> Bool
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Phrases")
                .font(.headline)
                .foregroundStyle(Color.vcPrimary)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(phrases, id: \.self) { phrase in
                        Button {
                            onSelect(phrase)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isPhraseCached(phrase) ? "checkmark.icloud.fill" : "icloud")
                                    .font(.caption)
                                    .foregroundStyle(isPhraseCached(phrase) ? Color.green : Color.secondary)
                                    .accessibilityHidden(true)
                                Text(phrase)
                                    .font(.body.weight(.medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(highContrast ? Color.black.opacity(0.12) : Color.white)
                            )
                            .overlay(
                                Capsule().stroke(highContrast ? Color.primary : Color.clear, lineWidth: highContrast ? 1.5 : 0)
                            )
                            .shadow(color: highContrast ? .clear : .vcCardShadow, radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            isPhraseCached(phrase)
                                ? "Quick phrase \(phrase), cached for offline"
                                : "Quick phrase \(phrase), needs internet to synthesize"
                        )
                        .frame(minHeight: 44)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
