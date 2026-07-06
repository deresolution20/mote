import Foundation
import Testing
@testable import LocalFlowCleanup

@Suite struct CleanupProviderSelectionTests {
    @Test func defaultsToOllamaWhenNoOverrideExists() throws {
        let defaults = try isolatedDefaults()

        let selected = CleanupProviderID.selected(environment: [:], defaults: defaults)

        #expect(selected == .ollama)
    }

    @Test func environmentOverrideSelectsMLX() throws {
        let defaults = try isolatedDefaults()
        defaults.set(CleanupProviderID.ollama.rawValue, forKey: CleanupProviderID.userDefaultsKey)

        let selected = CleanupProviderID.selected(
            environment: [CleanupProviderID.environmentKey: "mlx"],
            defaults: defaults
        )

        #expect(selected == .mlx)
    }

    @Test func userDefaultSelectsMLXWhenEnvironmentIsUnset() throws {
        let defaults = try isolatedDefaults()
        defaults.set(CleanupProviderID.mlx.rawValue, forKey: CleanupProviderID.userDefaultsKey)

        let selected = CleanupProviderID.selected(environment: [:], defaults: defaults)

        #expect(selected == .mlx)
    }

    @Test func invalidValuesFallBackToOllama() throws {
        let defaults = try isolatedDefaults()
        defaults.set("cloud", forKey: CleanupProviderID.userDefaultsKey)

        let selected = CleanupProviderID.selected(
            environment: [CleanupProviderID.environmentKey: "remote"],
            defaults: defaults
        )

        #expect(selected == .ollama)
    }

    @Test func factoryResolvesProviderIDsWithoutLoadingModels() {
        let factory = CleanupProviderFactory()

        #expect(factory.provider(for: .ollama).id == .ollama)
        #expect(factory.provider(for: .mlx).id == .mlx)
    }

    @Test func factoryUsesOllamaFallbackAfterMLX() {
        let factory = CleanupProviderFactory()

        #expect(factory.providerChain(for: .ollama).map(\.id) == [.ollama])
        #expect(factory.providerChain(for: .mlx).map(\.id) == [.mlx, .ollama])
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let suiteName = "LocalFlowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
