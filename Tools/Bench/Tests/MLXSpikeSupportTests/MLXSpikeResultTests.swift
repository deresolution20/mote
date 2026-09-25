import Foundation
import Testing
@testable import MLXSpikeSupport

@Suite struct MLXSpikeResultTests {
    @Test func encodesRequiredFailureResultFields() throws {
        let result = MLXSpikeResult.blocked(
            status: .modelNotSupported,
            prompt: "Clean this text.",
            blocker: "Model registry does not expose the approved Qwen model.",
            notes: ["Tokenizer loading did not run."]
        )

        let data = try JSONEncoder.localFlowSpike.encode(result)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["task"] as? String == "swift-native-mlx-provider-spike")
        #expect(object["model_id"] as? String == MLXSpikeConstants.modelID)
        #expect(object["status"] as? String == "model_not_supported")
        #expect(object["load_seconds"] is NSNull)
        #expect(object["warmup_seconds"] is NSNull)
        #expect(object["generation_seconds"] is NSNull)
        #expect((object["blockers"] as? [String]) == ["Model registry does not expose the approved Qwen model."])
        #expect((object["notes"] as? [String]) == ["Tokenizer loading did not run."])
    }

    @Test func encodesSuccessfulTimingFieldsAsSeconds() throws {
        let result = MLXSpikeResult.loadedAndGenerated(
            loadSeconds: 0.489,
            warmupSeconds: 0.180,
            generationSeconds: 0.240,
            prompt: "Clean this text.",
            rawOutput: "I think we should ship it Friday.",
            cleanedOutputCandidate: "I think we should ship it Friday.",
            notes: ["Loaded through MLX Swift LM."]
        )

        let data = try JSONEncoder.localFlowSpike.encode(result)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["status"] as? String == "loaded_and_generated")
        #expect(object["load_seconds"] as? Double == 0.489)
        #expect(object["warmup_seconds"] as? Double == 0.18)
        #expect(object["generation_seconds"] as? Double == 0.24)
        #expect(object["total_seconds"] as? Double == 0.909)
        #expect(object["raw_output"] as? String == "I think we should ship it Friday.")
    }
}
