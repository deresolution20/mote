import AVFoundation
import Foundation

enum StreamingHUDLatencyTuning {
    /// One streaming-model inference chunk, in model-rate (16 kHz mono) samples.
    /// 2,560 samples = 160 ms, the chunk size of the parakeetEou160ms variant;
    /// the model only runs once this many converted samples have accumulated.
    static let streamingModelChunkSamples = 2_560

    /// Sample rate the streaming model consumes (matches AudioCapture's target format).
    static let modelSampleRate: Double = 16_000

    /// Mic tap block size in *input-format* frames: the hardware frame count that
    /// resamples to exactly one model inference chunk, so each tap block can feed
    /// one streaming inference. The OS treats installTap's bufferSize as a request
    /// and may clamp it, so callers must not assume blocks arrive at this size.
    static func audioTapBufferFrames(inputSampleRate: Double) -> AVAudioFrameCount {
        AVAudioFrameCount(
            (Double(streamingModelChunkSamples) / modelSampleRate * inputSampleRate).rounded()
        )
    }

    static let captionAnimationDuration: TimeInterval = 0
}
