import Foundation

/// Facade kept for existing app call sites. Provider selection defaults to MLX
/// while preserving Ollama as an explicit rollback provider.
public enum Cleaner {
    private static let providerFactory = CleanupProviderFactory()

    public static var selectedProviderID: CleanupProviderID {
        CleanupProviderID.selected()
    }

    public static var displayName: String {
        providerFactory.provider(for: selectedProviderID).displayName
    }

    public static var model: String {
        providerFactory.provider(for: selectedProviderID).modelName
    }

    public static var keepAliveDefaultMinutes: Int {
        OllamaCleanupProvider.keepAliveDefaultMinutes
    }

    public static var keepAliveMinutes: Int {
        get { OllamaCleanupProvider.keepAliveMinutes }
        set { OllamaCleanupProvider.keepAliveMinutes = newValue }
    }

    public static func clean(_ raw: String) async -> String? {
        let result = await cleanResult(raw)
        return result.cleanedText
    }

    public static func cleanResult(_ raw: String) async -> CleanupAcceptanceResult {
        await CleanupAcceptanceRunner.run(raw: raw, providers: providerChain)
    }

    public static func warmUp() {
        providerFactory.provider(for: selectedProviderID).warmUp()
    }

    private static var providerChain: [any CleanupProvider] {
        providerFactory.providerChain(for: selectedProviderID)
    }
}
