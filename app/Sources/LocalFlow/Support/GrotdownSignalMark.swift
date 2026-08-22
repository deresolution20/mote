import SwiftUI

enum GrotdownSignalMarkMetrics {
    static let widths: [CGFloat] = [6, 6, 6, 6, 6]
    static let heights: [CGFloat] = [40, 26, 22, 12, 10]
    static let cornerRadius: CGFloat = 3
    static let pitch: CGFloat = 11
}

struct GrotdownSignalMark: View {
    var isActive = true

    var body: some View {
        HStack(alignment: .bottom, spacing: GrotdownSignalMarkMetrics.pitch - GrotdownSignalMarkMetrics.widths[0]) {
            ForEach(Array(GrotdownSignalMarkMetrics.heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: GrotdownSignalMarkMetrics.cornerRadius, style: .continuous)
                    .fill(isActive ? AnyShapeStyle(GrotdownTheme.signalGradient) : AnyShapeStyle(GrotdownTheme.Colors.mutedText))
                    .frame(
                        width: GrotdownSignalMarkMetrics.widths[index],
                        height: height
                    )
            }
        }
        .accessibilityLabel("Grotdown")
    }
}
