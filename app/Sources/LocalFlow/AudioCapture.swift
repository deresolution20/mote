import AVFoundation
import Foundation

/// Captures the default microphone into an in-memory 16 kHz mono Float32 buffer.
/// Same capture format the benchmark used, so measured accuracy carries over.
final class AudioCapture {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false
    )!

    func start(liveSamplesHandler: (([Float]) -> Void)? = nil) throws {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw NSError(domain: "LocalFlow", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "cannot convert mic format \(inputFormat)"
            ])
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let converter = self.converter else { return }
            let ratio = self.targetFormat.sampleRate / inputFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
            guard let out = AVAudioPCMBuffer(pcmFormat: self.targetFormat, frameCapacity: capacity) else { return }

            var fed = false
            let status = converter.convert(to: out, error: nil) { _, inputStatus in
                if fed {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                fed = true
                inputStatus.pointee = .haveData
                return buffer
            }
            guard status != .error, out.frameLength > 0, let channel = out.floatChannelData else { return }
            let chunk = Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
            self.lock.lock()
            self.samples.append(contentsOf: chunk)
            self.lock.unlock()
            liveSamplesHandler?(chunk)
        }

        try engine.start()
    }

    /// Stops capture and returns everything recorded since start().
    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
}
