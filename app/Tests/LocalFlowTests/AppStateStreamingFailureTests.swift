import Testing
@testable import LocalFlow

@MainActor
@Suite struct AppStateStreamingFailureTests {
    @Test func streamingFailureClearsHudTailAndSuppressesReleasedTailReuse() {
        let state = AppState()
        let token = state.testingBeginStreamingSession()

        state.testingSetCurrentHUDTail("...stale caption")
        #expect(
            state.testingHUDCaptionTailForReleasedSession("...stale caption", token: token) == "...stale caption"
        )

        state.testingMarkStreamingSessionFailed(token)

        #expect(state.testingStreamingSessionFailed)
        #expect(state.testingCurrentHUDTail == "")
        #expect(state.testingHUDCaptionTailForReleasedSession("...stale caption", token: token) == "")
    }

    @Test func staleTokenCannotMarkCurrentStreamingSessionFailed() {
        let state = AppState()
        let firstToken = state.testingBeginStreamingSession()
        _ = state.testingBeginStreamingSession()
        state.testingSetCurrentHUDTail("...current")

        state.testingMarkStreamingSessionFailed(firstToken)

        #expect(state.testingStreamingSessionFailed == false)
        #expect(state.testingCurrentHUDTail == "...current")
    }

    @Test func approvedPermissionsExposeAStartControlForModelDownloadConsent() {
        let state = AppState()
        state.micGranted = true
        state.accessibilityGranted = true
        state.status = .needsModelDownloadApproval

        #expect(state.menuRuntimeControl == .start)
    }
}
