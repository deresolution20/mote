import SwiftUI

enum MoteSignalMarkMetrics {
    static let widths: [CGFloat] = [6, 6, 6, 6, 6]
    static let heights: [CGFloat] = [40, 26, 22, 12, 10]
    static let cornerRadius: CGFloat = 3
    static let pitch: CGFloat = 11
}

struct MoteSignalMark: View {
    var isActive = true

    var body: some View {
        HStack(alignment: .bottom, spacing: MoteSignalMarkMetrics.pitch - MoteSignalMarkMetrics.widths[0]) {
            ForEach(Array(MoteSignalMarkMetrics.heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: MoteSignalMarkMetrics.cornerRadius, style: .continuous)
                    .fill(isActive ? AnyShapeStyle(MoteTheme.signalGradient) : AnyShapeStyle(MoteTheme.Colors.mutedText))
                    .frame(
                        width: MoteSignalMarkMetrics.widths[index],
                        height: height
                    )
            }
        }
        .accessibilityLabel("Mote")
    }
}
