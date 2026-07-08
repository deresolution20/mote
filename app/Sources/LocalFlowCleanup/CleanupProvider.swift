import Foundation

public enum CleanupProviderID: String, CaseIterable, Codable {
    case mlx
}

public protocol CleanupProvider: AnyObject {
    var id: CleanupProviderID { get }
    var displayName: String { get }
    var modelName: String { get }

    func clean(_ raw: String) async -> String?
    func cleanWithDiagnostics(_ raw: String) async -> CleanupProviderResult
    func warmUp()
}

public extension CleanupProvider {
    func cleanWithDiagnostics(_ raw: String) async -> CleanupProviderResult {
        if let cleaned = await clean(raw) {
            return .accepted(cleanedText: cleaned, rawCandidate: cleaned, sanitizedCandidate: cleaned)
        }
        return .rejected(
            rawCandidate: nil,
            sanitizedCandidate: nil,
            rejection: CleanupRejection(reason: .unknown)
        )
    }

    func warmUp() {}
}

public final class CleanupProviderFactory {
    public let provider: any CleanupProvider

    public init(provider: (any CleanupProvider)? = nil) {
        self.provider = provider ?? MLXCleanupProvider()
    }

    public var providerChain: [any CleanupProvider] {
        [provider]
    }
}
