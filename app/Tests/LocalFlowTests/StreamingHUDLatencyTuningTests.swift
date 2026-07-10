import AVFoundation
import Testing
@testable import LocalFlow

@Suite struct StreamingHUDLatencyTuningTests {
    @Test func tapBufferAt48kHzInputConvertsToOneModelChunk() {
        // 48 kHz mic: 7,680 input frames resample to 2,560 samples at 16 kHz.
        #expect(StreamingHUDLatencyTuning.audioTapBufferFrames(inputSampleRate: 48_000) == 7_680)
    }

    @Test func tapBufferAt44_1kHzInputConvertsToOneModelChunk() {
        // 44.1 kHz mic: 2,560 / 16,000 * 44,100 = 7,056 input frames.
        #expect(StreamingHUDLatencyTuning.audioTapBufferFrames(inputSampleRate: 44_100) == 7_056)
    }

    @Test func tapBufferMatchesModelChunkWhenInputIsModelRate() {
        #expect(
            StreamingHUDLatencyTuning.audioTapBufferFrames(
                inputSampleRate: StreamingHUDLatencyTuning.modelSampleRate
            ) == AVAudioFrameCount(StreamingHUDLatencyTuning.streamingModelChunkSamples)
        )
    }
}
