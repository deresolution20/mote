import MoteCleanup

struct HotkeyModifiers: OptionSet, Codable, Equatable, Sendable {
    let rawValue: UInt32

    static let command = Self(rawValue: 1 << 0)
    static let option = Self(rawValue: 1 << 1)
    static let control = Self(rawValue: 1 << 2)
    static let shift = Self(rawValue: 1 << 3)
}

struct HotkeyConfiguration: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: HotkeyModifiers

    static let `default` = Self(keyCode: 49, modifiers: [.option])

    var isValid: Bool {
        !modifiers.isEmpty
    }

    var displayName: String {
        let modifierLabel = [
            modifiers.contains(.control) ? "⌃" : "",
            modifiers.contains(.option) ? "⌥" : "",
            modifiers.contains(.shift) ? "⇧" : "",
            modifiers.contains(.command) ? "⌘" : "",
        ].joined()
        return "\(modifierLabel) \(keyLabel)"
    }

    private var keyLabel: String {
        switch keyCode {
        case 0: "A"
        case 1: "S"
        case 2: "D"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 18: "1"
        case 19: "2"
        case 20: "3"
        case 21: "4"
        case 22: "6"
        case 23: "5"
        case 24: "="
        case 25: "9"
        case 26: "7"
        case 27: "-"
        case 28: "8"
        case 29: "0"
        case 31: "O"
        case 32: "U"
        case 34: "I"
        case 35: "P"
        case 36: "Return"
        case 37: "L"
        case 38: "J"
        case 40: "K"
        case 45: "N"
        case 46: "M"
        case 48: "Tab"
        case 49: "Space"
        case 51: "Delete"
        default: "Key \(keyCode)"
        }
    }
}

struct HotkeyInteractionReducer {
    enum Event {
        case pressed
        case released
        case cancelled
    }

    enum Action: Equatable {
        case beginCapture
        case endCapture
        case cancelCapture
        case ignore
    }

    private let mode: CaptureMode
    private var isCapturing = false

    init(mode: CaptureMode) {
        self.mode = mode
    }

    mutating func handle(_ event: Event) -> Action {
        switch (mode, event) {
        case (.holdToTalk, .pressed):
            guard !isCapturing else { return .ignore }
            isCapturing = true
            return .beginCapture
        case (.holdToTalk, .released):
            guard isCapturing else { return .ignore }
            isCapturing = false
            return .endCapture
        case (.toggle, .pressed):
            isCapturing.toggle()
            return isCapturing ? .beginCapture : .endCapture
        case (.toggle, .released):
            return .ignore
        case (_, .cancelled):
            guard isCapturing else { return .ignore }
            isCapturing = false
            return .cancelCapture
        }
    }
}
