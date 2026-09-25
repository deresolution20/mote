import Foundation

/// Facade kept for existing app call sites. Cleanup is MLX-only; raw transcript
/// fallback is handled by `CleanupAcceptanceRunner` when MLX does not produce an
/// accepted result.
public enum Cleaner {
    private static let providerFactory = CleanupProviderFactory()

    public static var displayName: String {
        providerFactory.provider.displayName
    }

    public static var model: String {
        providerFactory.provider.modelName
    }

    public static func clean(_ raw: String) async -> String? {
        let result = await cleanResult(raw)
        return result.cleanedText
    }

    public static func cleanResult(_ raw: String) async -> CleanupAcceptanceResult {
        await CleanupAcceptanceRunner.run(raw: raw, providers: providerChain)
    }

    public static func warmUp() {
        providerFactory.provider.warmUp()
    }

    private static var providerChain: [any CleanupProvider] {
        providerFactory.providerChain
    }
}
