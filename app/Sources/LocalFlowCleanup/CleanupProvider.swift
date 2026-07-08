import Foundation

public enum CleanupProviderID: String, CaseIterable, Codable {
    case ollama
    case mlx

    public static let userDefaultsKey = "cleanupProvider"
    public static let environmentKey = "LOCALFLOW_CLEANUP_PROVIDER"

    public static func selected(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> CleanupProviderID {
        if let raw = environment[environmentKey], let provider = CleanupProviderID(rawValue: raw.lowercased()) {
            return provider
        }
        if let raw = defaults.string(forKey: userDefaultsKey), let provider = CleanupProviderID(rawValue: raw.lowercased()) {
            return provider
        }
        return .mlx
    }
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
    private let ollamaProvider = OllamaCleanupProvider()
    private let mlxProvider = MLXCleanupProvider()

    public init() {}

    public func provider(for id: CleanupProviderID) -> any CleanupProvider {
        switch id {
        case .ollama:
            return ollamaProvider
        case .mlx:
            return mlxProvider
        }
    }

    public func providerChain(for id: CleanupProviderID) -> [any CleanupProvider] {
        switch id {
        case .ollama:
            return [ollamaProvider]
        case .mlx:
            return [mlxProvider, ollamaProvider]
        }
    }
}
