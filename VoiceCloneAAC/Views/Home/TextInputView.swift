import SwiftUI

struct TextInputView: View {
    @Binding var text: String
    var offlineHint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .font(.title3)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 160)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .vcCardShadow, radius: 2, x: 0, y: 1)
                )
                .accessibilityLabel("Type what you want to say")

            if let offlineHint {
                Text(offlineHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(offlineHint)
            }
        }
    }
}
