import Foundation

/// Cleans a raw transcript with a small local LLM via Ollama (localhost only —
/// the dictation path never touches the network). The raw transcript is always
/// kept by the caller; every failure mode here falls back to raw.
struct Cleaner {
    static let model = "gemma3:4b"
    private static let baseURL = URL(string: "http://localhost:11434")!
    /// Keep the model resident between dictations — cold load costs ~2 s.
    private static let keepAlive = "60m"
    /// Past this, pasting raw beats making the user wait.
    private static let timeout: TimeInterval = 6

    /// Few-shot examples are load-bearing: without them gemma3:4b drops hedges
    /// ("i think", "probably") as if they were filler — a meaning change.
    /// Validated in Phase 0 (bench/SYNTH_CLEANUP.md: 19/20 meaning-preserving).
    private static let systemPrompt = """
    You clean up dictated text: remove only filler words (um, uh, like, you know, \
    so, i mean), false starts, and stutter repetitions. Fix punctuation and \
    capitalization. Keep ALL other words — hedges like i think, maybe, probably \
    are meaning and must stay. Never add words. Output only the cleaned text.

    Example:
    Input: um so like i think we should uh ship it friday
    Output: I think we should ship it Friday.

    Example:
    Input: yeah the the uh deploy is maybe broken i think
    Output: The deploy is maybe broken, I think.
    """

    private struct GenerateRequest: Encodable {
        let model: String
        let system: String
        let prompt: String
        let stream: Bool
        let keep_alive: String
        let options: Options
        struct Options: Encodable {
            let temperature: Double
            let num_predict: Int
        }
    }

    private struct GenerateResponse: Decodable {
        let response: String
    }

    /// Returns the cleaned text, or nil when the caller should paste raw.
    static func clean(_ raw: String) async -> String? {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        do {
            request.httpBody = try JSONEncoder().encode(GenerateRequest(
                model: model,
                system: systemPrompt,
                prompt: raw,
                stream: false,
                keep_alive: keepAlive,
                options: .init(temperature: 0.1, num_predict: 256)
            ))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let cleaned = try JSONDecoder().decode(GenerateResponse.self, from: data)
                .response.trimmingCharacters(in: .whitespacesAndNewlines)
            return plausible(cleaned, raw: raw) ? cleaned : nil
        } catch {
            return nil
        }
    }

    /// Cheap hallucination guard: cleanup only ever removes fillers and fixes
    /// punctuation, so the output should be non-empty, single-utterance-sized,
    /// and not dramatically longer or shorter than the input.
    private static func plausible(_ cleaned: String, raw: String) -> Bool {
        guard !cleaned.isEmpty else { return false }
        let rawWords = raw.split(separator: " ").count
        let cleanedWords = cleaned.split(separator: " ").count
        if cleanedWords > rawWords + 3 { return false }          // added content
        if rawWords >= 6, cleanedWords < rawWords / 3 { return false } // gutted content
        return true
    }

    /// Fire-and-forget warm-up so the first dictation doesn't pay the ~2 s
    /// model load. keep_alive then holds it resident.
    static func warmUp() {
        Task.detached(priority: .utility) {
            _ = await clean("warm up")
        }
    }
}
