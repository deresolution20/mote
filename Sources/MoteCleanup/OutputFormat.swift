public enum OutputFormat: String, Codable, CaseIterable, Sendable {
    case plain
    case markdown
}

public enum CaptureMode: String, Codable, CaseIterable, Sendable {
    case holdToTalk
    case toggle
}
