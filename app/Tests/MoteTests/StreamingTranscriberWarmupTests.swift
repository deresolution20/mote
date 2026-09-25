@preconcurrency import AVFoundation
import FluidAudio
import Testing
@testable import Mote

@Suite struct StreamingTranscriberWarmupTests {
    @Test func warmUpProcessesOneStreamingChunkAndLeavesManagerReset() async throws {
        let manager = WarmupRecordingStreamingManager()
        let transcriber = StreamingTranscriber(managerFactory: { manager })

        try await transcriber.load()
        #expect(await transcriber.isAvailable == false)

        try await transcriber.warmUp()

        #expect(await transcriber.isAvailable)
        #expect(await transcriber.hasFailedCurrentSession == false)
        #expect(
            await manager.recordedEvents
                == ["load", "reset", "append:2560", "process", "reset"]
        )
    }

    @Test func warmUpFailureDisablesStreamingAndRestoresCleanSessionState() async throws {
        let manager = WarmupRecordingStreamingManager(shouldFailProcessing: true)
        let transcriber = StreamingTranscriber(managerFactory: { manager })
        try await transcriber.load()

        var warmupFailed = false
        do {
            try await transcriber.warmUp()
        } catch {
            warmupFailed = true
        }

        #expect(warmupFailed)
        #expect(await transcriber.isAvailable == false)
        #expect(await transcriber.hasFailedCurrentSession == false)
        #expect(
            await manager.recordedEvents
                == ["load", "reset", "append:2560", "process", "reset"]
        )
    }

    @Test func appendBeforeWarmupIsDroppedAndReportsNoInference() async throws {
        let manager = WarmupRecordingStreamingManager()
        let transcriber = StreamingTranscriber(managerFactory: { manager })
        try await transcriber.load()

        let inferenceRan = await transcriber.append(samples: [0.1, 0.2])

        #expect(inferenceRan == false)
        #expect(await manager.recordedEvents == ["load"])
    }

    @Test func appendAfterWarmupRunsInferenceAndReportsIt() async throws {
        let manager = WarmupRecordingStreamingManager()
        let transcriber = StreamingTranscriber(managerFactory: { manager })
        try await transcriber.load()
        try await transcriber.warmUp()

        let inferenceRan = await transcriber.append(samples: [0.1, 0.2])

        #expect(inferenceRan)
        #expect(
            await manager.recordedEvents
                == ["load", "reset", "append:2560", "process", "reset", "append:2", "process"]
        )
    }
}

private actor WarmupRecordingStreamingManager: StreamingAsrManager {
    enum TestError: Error {
        case processFailed
    }

    let displayName = "Warmup test manager"
    private let shouldFailProcessing: Bool
    private var events: [String] = []
    private var partialCallback: (@Sendable (String) -> Void)?

    init(shouldFailProcessing: Bool = false) {
        self.shouldFailProcessing = shouldFailProcessing
    }

    var recordedEvents: [String] {
        events
    }

    func loadModels() async throws {
        events.append("load")
    }

    func appendAudio(_ buffer: AVAudioPCMBuffer) throws {
        events.append("append:\(buffer.frameLength)")
    }

    func processBufferedAudio() async throws {
        events.append("process")
        if shouldFailProcessing {
            throw TestError.processFailed
        }
    }

    func finish() async throws -> String {
        ""
    }

    func reset() async throws {
        events.append("reset")
    }

    func cleanup() async {
        events.removeAll()
    }

    func setPartialTranscriptCallback(_ callback: @escaping @Sendable (String) -> Void) {
        partialCallback = callback
    }

    func getPartialTranscript() -> String {
        ""
    }
}
