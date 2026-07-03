import Foundation
import ArgumentParser

@main
struct Bench: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bench",
        abstract: "Local Flow Phase-0 ASR benchmark harness.",
        subcommands: [Prepare.self, Record.self, Run.self, Cleanup.self]
    )
}

// MARK: - Shared options

struct SamplesDirOption: ParsableArguments {
    @Option(name: .long, help: "Directory holding WAV samples and manifest.json.")
    var samplesDir: String = "samples"

    var url: URL { URL(fileURLWithPath: samplesDir) }
}

func parseEngines(_ raw: [String]) throws -> [EngineID] {
    try raw.map {
        guard let id = EngineID(rawValue: $0) else { throw BenchError.unknownEngine($0) }
        return id
    }
}

// MARK: - prepare

struct Prepare: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Download/load every engine's model once (setup-time network is OK)."
    )

    @Option(parsing: .upToNextOption, help: "Engines to prepare.")
    var engines: [String] = EngineID.allCases.map(\.rawValue)

    func run() async throws {
        for id in try parseEngines(engines) {
            let engine = id.make()
            print("→ loading \(engine.name) …")
            let start = Date()
            do {
                try await engine.load()
                print("  ✓ ready in \(fmt(Date().timeIntervalSince(start)))")
            } catch {
                print("  ✗ FAILED: \(error)")
            }
        }
    }
}

// MARK: - record

struct Record: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Interactively record the utterance test set (16 kHz mono WAV + manifest)."
    )

    @OptionGroup var samples: SamplesDirOption

    @Option(help: "How many utterances to collect this session.")
    var count: Int = 20

    func run() async throws {
        let dir = samples.url
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var manifest = try Manifest.load(from: dir)
        let startIndex = manifest.samples.count

        print("""
        Recording \(count) utterances into \(dir.path)
        For each one: Enter starts recording, Enter again stops it, then you
        confirm the reference transcript — the words you ACTUALLY said, fillers included.
        Press Ctrl-C to abort; completed takes are already saved.
        """)

        for n in 0..<count {
            let index = startIndex + n
            let id = String(format: "%02d", index + 1)
            let suggestion = SuggestedUtterances.all[index % SuggestedUtterances.all.count]

            print("\n[\(id)] Suggested (speak naturally, improvising is fine):")
            print("    “\(suggestion)”")
            print("    Press Enter to START recording…", terminator: "")
            _ = readLine()

            let fileName = "\(id).wav"
            let fileURL = dir.appendingPathComponent(fileName)
            let recorder = Recorder()
            try recorder.start(writingTo: fileURL)
            print("    ● recording — press Enter to STOP…", terminator: "")
            _ = readLine()
            recorder.stop()
            print("    saved \(fileName) (\(String(format: "%.1f", AudioIO.duration(fileURL))) s)")

            print("    Reference transcript [Enter = suggested text]: ", terminator: "")
            let typed = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
            let reference = typed.isEmpty ? suggestion : typed

            manifest.samples.append(Sample(id: id, file: fileName, reference: reference))
            try manifest.save(to: dir)
        }
        print("\nDone — \(manifest.samples.count) samples in manifest.")
    }
}

// MARK: - run

struct Run: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Benchmark every engine over the recorded samples; write RESULTS.md."
    )

    @OptionGroup var samples: SamplesDirOption

    @Option(parsing: .upToNextOption, help: "Engines to benchmark.")
    var engines: [String] = EngineID.allCases.map(\.rawValue)

    @Option(help: "Markdown report output path.")
    var output: String = "RESULTS.md"

    struct SampleResult {
        let id: String
        let latency: Double
        let wer: Double
        let hypothesis: String
        let audioSeconds: Double
    }

    struct EngineReport {
        let name: String
        let loadTime: Double
        let warmupTime: Double
        let results: [SampleResult]
        let failure: String?
    }

    func run() async throws {
        let dir = samples.url
        let manifest = try Manifest.load(from: dir)
        guard !manifest.samples.isEmpty else { throw BenchError.noSamples(dir.path) }

        var reports: [EngineReport] = []
        for id in try parseEngines(engines) {
            let engine = id.make()
            print("\n=== \(engine.name) ===")
            do {
                let loadStart = Date()
                try await engine.load()
                let loadTime = Date().timeIntervalSince(loadStart)
                print("loaded in \(fmt(loadTime))")

                // Warm up on the first sample so Core ML / ANE compilation
                // doesn't pollute the first timed measurement.
                let warmupURL = dir.appendingPathComponent(manifest.samples[0].file)
                let warmupStart = Date()
                _ = try await engine.transcribe(warmupURL)
                let warmupTime = Date().timeIntervalSince(warmupStart)
                print("warmup in \(fmt(warmupTime))")

                var results: [SampleResult] = []
                for sample in manifest.samples {
                    let url = dir.appendingPathComponent(sample.file)
                    let start = Date()
                    let hypothesis = try await engine.transcribe(url)
                    let latency = Date().timeIntervalSince(start)
                    let wer = wordErrorRate(reference: sample.reference, hypothesis: hypothesis)
                    results.append(SampleResult(
                        id: sample.id, latency: latency, wer: wer,
                        hypothesis: hypothesis, audioSeconds: AudioIO.duration(url)
                    ))
                    print("  [\(sample.id)] \(fmt(latency))  WER \(fmtPct(wer))  “\(hypothesis)”")
                }
                reports.append(EngineReport(
                    name: engine.name, loadTime: loadTime, warmupTime: warmupTime,
                    results: results, failure: nil
                ))
            } catch {
                print("  ✗ FAILED: \(error)")
                reports.append(EngineReport(
                    name: engine.name, loadTime: 0, warmupTime: 0, results: [], failure: "\(error)"
                ))
            }
        }

        let markdown = renderReport(reports: reports, sampleCount: manifest.samples.count, manifest: manifest)
        try markdown.write(toFile: output, atomically: true, encoding: .utf8)
        print("\nReport written to \(output)")
    }

    func renderReport(reports: [EngineReport], sampleCount: Int, manifest: Manifest) -> String {
        var md = """
        # ASR benchmark results

        - Samples: \(sampleCount) short, filler-heavy dictation utterances (Brice's voice, 16 kHz mono)
        - Latency = wall-clock batch transcription of the whole file, model pre-loaded and warmed
          (a proxy for end-of-speech latency; streaming behavior is evaluated separately in Phase 1)
        - WER = word-level Levenshtein vs verbatim reference (fillers included), case/punctuation-insensitive

        ## Summary

        | Engine | Load | Warmup (1st transcribe) | Median latency | p90 latency | Mean WER |
        | --- | --- | --- | --- | --- | --- |

        """
        for r in reports {
            if let failure = r.failure {
                md += "| \(r.name) | — | — | — | — | FAILED: \(failure) |\n"
            } else {
                let lat = r.results.map(\.latency)
                let wer = r.results.map(\.wer)
                md += "| \(r.name) | \(fmt(r.loadTime)) | \(fmt(r.warmupTime)) | \(fmt(lat.median)) | \(fmt(lat.p90)) | \(fmtPct(wer.mean)) |\n"
            }
        }

        md += "\n## Per-sample details\n"
        for r in reports where r.failure == nil {
            md += "\n### \(r.name)\n\n| id | audio | latency | WER | hypothesis |\n| --- | --- | --- | --- | --- |\n"
            for s in r.results {
                let hyp = s.hypothesis.replacingOccurrences(of: "|", with: "\\|")
                md += "| \(s.id) | \(String(format: "%.1f s", s.audioSeconds)) | \(fmt(s.latency)) | \(fmtPct(s.wer)) | \(hyp) |\n"
            }
        }

        md += "\n## References\n\n| id | reference |\n| --- | --- |\n"
        for s in manifest.samples {
            md += "| \(s.id) | \(s.reference.replacingOccurrences(of: "|", with: "\\|")) |\n"
        }
        return md
    }
}

// MARK: - cleanup

struct Cleanup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Time the Ollama cleanup hop over the sample transcripts; write CLEANUP.md."
    )

    @OptionGroup var samples: SamplesDirOption

    @Option(parsing: .upToNextOption, help: "Ollama models to compare.")
    var models: [String] = ["gemma3:4b", "gemma4:26b"]

    @Option(help: "Ollama base URL (must stay on localhost).")
    var ollamaURL: String = "http://localhost:11434"

    @Option(help: "Markdown report output path.")
    var output: String = "CLEANUP.md"

    func run() async throws {
        guard let base = URL(string: ollamaURL), base.host == "localhost" || base.host == "127.0.0.1" else {
            throw BenchError.ollama("refusing non-localhost URL '\(ollamaURL)' (offline guardrail)")
        }
        let manifest = try Manifest.load(from: samples.url)
        guard !manifest.samples.isEmpty else { throw BenchError.noSamples(samples.url.path) }

        var md = """
        # Ollama cleanup-hop benchmark

        - Input: the \(manifest.samples.count) verbatim reference transcripts (fillers included)
        - temperature 0.1, num_predict 256, non-streaming `/api/generate`
        - Latency includes Ollama model residency effects — first call per model may be slower (load)

        """

        for model in models {
            let cleaner = OllamaCleanup(baseURL: base, model: model)
            print("\n=== \(model) ===")
            var latencies: [Double] = []
            var rows = ""
            for sample in manifest.samples {
                do {
                    let result = try await cleaner.clean(sample.reference)
                    latencies.append(result.latency)
                    let cleaned = result.cleaned.replacingOccurrences(of: "|", with: "\\|")
                    rows += "| \(sample.id) | \(fmt(result.latency)) | \(cleaned) |\n"
                    print("  [\(sample.id)] \(fmt(result.latency))  “\(result.cleaned)”")
                } catch {
                    rows += "| \(sample.id) | FAILED | \(error) |\n"
                    print("  [\(sample.id)] ✗ \(error)")
                }
            }
            md += """

            ## \(model)

            Median \(fmt(latencies.median)) · p90 \(fmt(latencies.p90)) · first call \(fmt(latencies.first ?? 0))

            | id | latency | cleaned output (verify meaning by eye) |
            | --- | --- | --- |
            \(rows)
            """
        }

        try md.write(toFile: output, atomically: true, encoding: .utf8)
        print("\nReport written to \(output)")
    }
}
