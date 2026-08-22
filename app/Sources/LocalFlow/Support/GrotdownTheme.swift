import SwiftUI

enum GrotdownTheme {
    enum Colors {
        static let canvas = Color(red: 8 / 255, green: 9 / 255, blue: 11 / 255)
        static let surface = Color(red: 22 / 255, green: 24 / 255, blue: 30 / 255)
        static let raised = Color(red: 27 / 255, green: 30 / 255, blue: 36 / 255)
        static let input = Color(red: 14 / 255, green: 16 / 255, blue: 20 / 255)
        static let border = Color(red: 42 / 255, green: 46 / 255, blue: 55 / 255)

        static let primaryText = Color(red: 244 / 255, green: 244 / 255, blue: 246 / 255)
        static let secondaryText = Color(red: 177 / 255, green: 183 / 255, blue: 194 / 255)
        static let mutedText = Color(red: 121 / 255, green: 128 / 255, blue: 141 / 255)

        static let signalStart = Color(red: 250 / 255, green: 222 / 255, blue: 42 / 255)
        static let signalEnd = Color(red: 240 / 255, green: 90 / 255, blue: 40 / 255)
        static let success = Color(red: 73 / 255, green: 212 / 255, blue: 145 / 255)
        static let danger = Color(red: 255 / 255, green: 104 / 255, blue: 104 / 255)
    }

    enum Typography {
        static func display(_ size: CGFloat) -> Font {
            .custom("Space Grotesk", size: size, relativeTo: .title)
        }

        static func body(_ size: CGFloat) -> Font {
            .custom("Hanken Grotesk", size: size, relativeTo: .body)
        }

        static func mono(_ size: CGFloat) -> Font {
            .custom("Space Mono", size: size, relativeTo: .body)
        }
    }

    enum Metrics {
        static let panelWidth: CGFloat = 340
        static let panelCornerRadius: CGFloat = 16
        static let controlCornerRadius: CGFloat = 10
        static let compactSpacing: CGFloat = 8
        static let standardSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 20
    }

    enum Motion {
        static let fast: Double = 0.12
        static let base: Double = 0.20
        static let slow: Double = 0.32
    }

    static var signalGradient: LinearGradient {
        LinearGradient(
            colors: [Colors.signalStart, Colors.signalEnd],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
