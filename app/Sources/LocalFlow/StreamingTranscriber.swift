@preconcurrency import AVFoundation
import FluidAudio
import Foundation

actor StreamingTranscriber {
    typealias PartialHandler = @MainActor @Sendable (String) -> Void

    private var manager: (any StreamingAsrManager)?
    private var partialHandler: PartialHandler?
    private var available = false
    private var failedCurrentSession = false

    var isAvailable: Bool {
        available
    }

    func load() async throws {
        guard manager == nil else {
            available = true
            return
        }

        let manager = StreamingModelVariant.parakeetEou160ms.createManager()
        await manager.setPartialTranscriptCallback { [weak self] text in
            Task {
                await self?.emitPartial(text)
            }
        }
        try await manager.loadModels()
        self.manager = manager
        available = true
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

    func append(samples: [Float]) async {
        guard !failedCurrentSession, let manager, !samples.isEmpty else { return }

        do {
            let buffer = try Self.makeBuffer(samples: samples)
            try await manager.appendAudio(buffer)
            try await manager.processBufferedAudio()
        } catch {
            failedCurrentSession = true
        }
    }

    func finish() async throws -> String {
        guard !failedCurrentSession, let manager else { return "" }

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
            throw NSError(domain: "LocalFlow", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "could not allocate streaming audio buffer"
            ])
        }

        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "LocalFlow", code: 4, userInfo: [
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
