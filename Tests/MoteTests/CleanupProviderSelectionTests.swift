import Foundation
import Testing
@testable import MoteCleanup

@Suite struct CleanupProviderSelectionTests {
    @Test func cleanupProviderIDsAreMLXOnly() {
        #expect(CleanupProviderID.allCases == [.mlx])
    }

    @Test func factoryBuildsSingleMLXProviderChainWithoutLoadingModels() {
        let factory = CleanupProviderFactory()

        #expect(factory.provider.id == .mlx)
        #expect(factory.providerChain.map(\.id) == [.mlx])
    }
}
