import Testing
@testable import LocalFlow

@Suite struct AudioCaptureLifecycleTests {
    @Test func createsFreshAudioEngineForEachCaptureSession() {
        let first = AudioCapture.makeEngineForCapture()
        let second = AudioCapture.makeEngineForCapture()

        #expect(first !== second)
    }

    @Test func reportsTheRMSLevelOfConvertedSamples() {
        #expect(AudioCapture.rmsLevel(samples: []) == 0)
        #expect(abs(AudioCapture.rmsLevel(samples: [0, 1]) - 0.70710678) < 0.0001)
    }
}
