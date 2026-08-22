import AVFoundation
import AudioToolbox
import Foundation

/// Captures the default microphone into an in-memory 16 kHz mono Float32 buffer.
/// Same capture format the benchmark used, so measured accuracy carries over.
final class AudioCapture {
    private var engine: AVAudioEngine?
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false
    )!

    static func makeEngineForCapture() -> AVAudioEngine {
        AVAudioEngine()
    }

    func start(
        deviceID: UInt32? = nil,
        liveSamplesHandler: (([Float]) -> Void)? = nil,
        levelHandler: ((Double) -> Void)? = nil
    ) throws {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()

        let engine = Self.makeEngineForCapture()
        self.engine = engine
        let input = engine.inputNode
        if let deviceID {
            try configure(inputNode: input, deviceID: deviceID)
        }
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw NSError(domain: "LocalFlow", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "cannot convert mic format \(inputFormat)"
            ])
        }
        self.converter = converter

        input.installTap(
            onBus: 0,
            bufferSize: StreamingHUDLatencyTuning.audioTapBufferFrames(
                inputSampleRate: inputFormat.sampleRate
            ),
            format: inputFormat
        ) { [weak self] buffer, _ in
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
            levelHandler?(Self.rmsLevel(samples: chunk))
            liveSamplesHandler?(chunk)
        }

        do {
            try engine.start()
        } catch {
            // Leaving the tap installed would make the next start()'s installTap
            // raise an uncatchable NSException on the already-tapped bus.
            input.removeTap(onBus: 0)
            self.converter = nil
            throw error
        }
    }

    /// Stops capture and returns everything recorded since start().
    func stop() -> [Float] {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            self.engine = nil
        }
        converter = nil
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    static func rmsLevel(samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(0.0) { partial, sample in
            partial + Double(sample * sample)
        } / Double(samples.count)
        return sqrt(meanSquare)
    }

    private func configure(inputNode: AVAudioInputNode, deviceID: UInt32) throws {
        guard let audioUnit = inputNode.audioUnit else {
            throw NSError(
                domain: "Grotdown.AudioCapture",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "microphone audio unit is unavailable"]
            )
        }
        var selectedDeviceID = AudioDeviceID(deviceID)
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selectedDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw NSError(
                domain: "Grotdown.AudioCapture",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "could not select microphone device \(deviceID)"]
            )
        }
    }
}
