import Testing
@testable import LocalFlow

@Suite struct AudioCaptureLifecycleTests {
    @Test func createsFreshAudioEngineForEachCaptureSession() {
        let first = AudioCapture.makeEngineForCapture()
        let second = AudioCapture.makeEngineForCapture()

        #expect(first !== second)
    }
}
