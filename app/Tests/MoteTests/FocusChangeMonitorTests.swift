import ApplicationServices
import Testing
@testable import Mote

@Suite struct FocusChangeMonitorTests {
    @Test func invalidationIsMonotonic() {
        let state = FocusChangeState()

        #expect(!state.invalidated)
        state.invalidate()
        #expect(state.invalidated)
        state.invalidate()
        #expect(state.invalidated)
    }

    @Test func applicationActivationInvalidatesOnlyWhenTheProcessChanges() {
        #expect(!FocusChangeMonitor.shouldInvalidate(activatedPID: 42, capturedPID: 42))
        #expect(FocusChangeMonitor.shouldInvalidate(activatedPID: 43, capturedPID: 42))
    }

    @Test func focusedElementObservationIsRequiredButWindowObservationIsOptional() {
        #expect(FocusChangeMonitor.canProtectCapture(
            focusedElementResult: .success,
            focusedWindowResult: .notificationUnsupported
        ))
        #expect(!FocusChangeMonitor.canProtectCapture(
            focusedElementResult: .notificationUnsupported,
            focusedWindowResult: .success
        ))
    }
}
