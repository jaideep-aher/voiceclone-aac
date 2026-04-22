import SwiftUI

struct WaveformView: View {
    let samples: [CGFloat]
    var activeColor: Color = .vcPrimary

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(activeColor.opacity(0.35 + Double(min(level, 1)) * 0.65))
                        .frame(height: max(4, geo.size.height * min(level, 1)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityLabel("Recording level visualization")
        .accessibilityHidden(true)
    }
}
