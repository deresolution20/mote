@preconcurrency import AVFoundation
import FluidAudio
import Foundation

actor StreamingTranscriber {
    typealias PartialHandler = @MainActor @Sendable (String) -> Void
    typealias ManagerFactory = @Sendable () -> any StreamingAsrManager

    private let managerFactory: ManagerFactory
    /// One inference chunk for the manager the factory builds, in 16 kHz samples.
    /// Must match the injected variant's chunk size or warmUp() buffers audio
    /// without ever running inference and the warmup is a silent no-op.
    private let modelChunkSamples: Int
    private var manager: (any StreamingAsrManager)?
    private var partialHandler: PartialHandler?
    private var available = false
    private var failedCurrentSession = false

    init(
        managerFactory: @escaping ManagerFactory = {
            StreamingModelVariant.parakeetEou160ms.createManager()
        },
        modelChunkSamples: Int = StreamingHUDLatencyTuning.streamingModelChunkSamples
    ) {
        self.managerFactory = managerFactory
        self.modelChunkSamples = modelChunkSamples
    }

    var isAvailable: Bool {
        available
    }

    var hasFailedCurrentSession: Bool {
        failedCurrentSession
    }

    func load() async throws {
        guard manager == nil else { return }

        let manager = managerFactory()
        await manager.setPartialTranscriptCallback { [weak self] text in
            Task {
                await self?.emitPartial(text)
            }
        }
        try await manager.loadModels()
        self.manager = manager
    }

    func warmUp() async throws {
        guard let manager else {
            throw NSError(domain: "Mote", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "streaming model is not loaded"
            ])
        }

        available = false
        failedCurrentSession = false
        do {
            try await manager.reset()
            let silence = Array(repeating: Float.zero, count: modelChunkSamples)
            let buffer = try Self.makeBuffer(samples: silence)
            try await manager.appendAudio(buffer)
            try await manager.processBufferedAudio()
            try await manager.reset()
            available = true
        } catch {
            try? await manager.reset()
            available = false
            failedCurrentSession = false
            throw error
        }
    }

    func setPartialHandler(_ handler: PartialHandler?) {
        partialHandler = handler
    }

    func reset() async {
        failedCurrentSession = false
        guard let manager else { return }

        do {
            try await manager.reset()
        } catch {
            failedCurrentSession = true
        }
    }

    /// Returns true only when the samples were actually fed through inference,
    /// so callers can trust it for latency accounting.
    @discardableResult
    func append(samples: [Float]) async -> Bool {
        guard available, !failedCurrentSession, let manager, !samples.isEmpty else { return false }

        do {
            let buffer = try Self.makeBuffer(samples: samples)
            try await manager.appendAudio(buffer)
            try await manager.processBufferedAudio()
            return true
        } catch {
            failedCurrentSession = true
            return false
        }
    }

    func finish() async throws -> String {
        guard available, !failedCurrentSession, let manager else { return "" }

        do {
            let text = try await manager.finish()
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            failedCurrentSession = true
            return ""
        }
    }

    private func emitPartial(_ text: String) async {
        guard let partialHandler else { return }
        await partialHandler(text)
    }

    private static func makeBuffer(samples: [Float]) throws -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else {
            throw NSError(domain: "Mote", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "could not allocate streaming audio buffer"
            ])
        }

        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "Mote", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "streaming audio buffer missing channel data"
            ])
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            channelData[0].update(from: baseAddress, count: samples.count)
        }
        return buffer
    }
}
