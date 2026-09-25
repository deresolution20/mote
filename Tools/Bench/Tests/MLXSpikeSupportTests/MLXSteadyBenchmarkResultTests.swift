import Foundation
import Testing
@testable import MLXSpikeSupport

@Suite struct MLXSteadyBenchmarkResultTests {
    @Test func computesSummaryFromSteadyStateLatencies() {
        let summary = MLXSteadyBenchmarkSummary(latencies: [0.1444, 0.2012, 0.1876, 0.1551, 0.3019])

        #expect(summary.sampleCount == 5)
        #expect(summary.minSeconds == 0.144)
        #expect(summary.maxSeconds == 0.302)
        #expect(summary.meanSeconds == 0.198)
        #expect(summary.medianSeconds == 0.188)
        #expect(summary.p50Seconds == 0.188)
        #expect(summary.p90Seconds == 0.302)
        #expect(summary.p95Seconds == 0.302)
    }

    @Test func encodesSteadyStateBenchmarkContract() throws {
        let sample = MLXSteadyBenchmarkSample(
            id: "01",
            reference: "um, so I think we should ship it Friday",
            prompt: "Clean this dictated text.\n\nInput: um, so I think we should ship it Friday",
            latencySeconds: 0.1444,
            rawOutput: "I think we should ship it Friday.",
            cleanedOutputCandidate: "I think we should ship it Friday."
        )
        let result = MLXSteadyBenchmarkResult.completed(
            manifestPath: "bench/samples/manifest.json",
            loadSeconds: 0.963,
            warmupSeconds: 0.140,
            benchmarkSeconds: 0.501,
            samples: [
                sample,
                MLXSteadyBenchmarkSample(
                    id: "02",
                    reference: "yeah so basically the uh the dashboard is is broken again",
                    prompt: "Clean this dictated text.\n\nInput: yeah so basically the uh the dashboard is is broken again",
                    latencySeconds: 0.2012,
                    rawOutput: "Yeah, the dashboard is broken again.",
                    cleanedOutputCandidate: "Yeah, the dashboard is broken again."
                ),
            ],
            notes: ["One model load, one warmup, repeated cleanup calls in one process."],
            swiftToolchain: "Apple Swift",
            machineContext: ["architecture": "arm64"]
        )

        let data = try JSONEncoder.localFlowSpike.encode(result)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let summary = try #require(object["summary"] as? [String: Any])
        let samples = try #require(object["samples"] as? [[String: Any]])

        #expect(object["task"] as? String == "swift-native-mlx-steady-state-cleanup-benchmark")
        #expect(object["status"] as? String == "completed")
        #expect(object["model_id"] as? String == MLXSpikeConstants.modelID)
        #expect(object["load_seconds"] as? Double == 0.963)
        #expect(object["warmup_seconds"] as? Double == 0.14)
        #expect(object["benchmark_seconds"] as? Double == 0.501)
        #expect(summary["sample_count"] as? Int == 2)
        #expect(summary["median_seconds"] as? Double == 0.173)
        #expect(samples.count == 2)
        #expect(samples[0]["latency_seconds"] as? Double == 0.144)
        #expect(samples[0]["cleaned_output_candidate"] as? String == "I think we should ship it Friday.")
    }

    @Test func encodesBlockedResultWithNullExecutionFields() throws {
        let result = MLXSteadyBenchmarkResult.blocked(
            status: .packageOrToolchainBlocked,
            manifestPath: "bench/samples/manifest.json",
            blocker: "Runtime metallib was not found.",
            notes: ["Run swift run mlx-metallib-prepare first."]
        )

        let data = try JSONEncoder.localFlowSpike.encode(result)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["status"] as? String == "package_or_toolchain_blocked")
        #expect(object["load_seconds"] is NSNull)
        #expect(object["warmup_seconds"] is NSNull)
        #expect(object["benchmark_seconds"] is NSNull)
        #expect(object["summary"] is NSNull)
        #expect((object["blockers"] as? [String]) == ["Runtime metallib was not found."])
    }
}
