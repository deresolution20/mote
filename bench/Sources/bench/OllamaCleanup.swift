import Foundation

/// Times the cleanup hop: raw transcript → local Ollama → cleaned text.
/// Talks only to localhost — the offline guardrail holds.
struct OllamaCleanup {
    let baseURL: URL
    let model: String

    // Few-shot examples are load-bearing: without them gemma3:4b drops hedges
    // ("i think", "probably") as if they were filler — a meaning change.
    static let systemPrompt = """
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

    struct Result {
        let cleaned: String
        let latency: TimeInterval
    }

    private struct GenerateRequest: Encodable {
        let model: String
        let system: String
        let prompt: String
        let stream: Bool
        let options: Options
        struct Options: Encodable {
            let temperature: Double
            let num_predict: Int
        }
    }

    private struct GenerateResponse: Decodable {
        let response: String
    }

    func clean(_ rawTranscript: String) async throws -> Result {
        let request = GenerateRequest(
            model: model,
            system: Self.systemPrompt,
            prompt: rawTranscript,
            stream: false,
            options: .init(temperature: 0.1, num_predict: 256)
        )
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 300

        let start = Date()
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        let latency = Date().timeIntervalSince(start)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw BenchError.ollama("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1): \(body)")
        }
        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return Result(
            cleaned: decoded.response.trimmingCharacters(in: .whitespacesAndNewlines),
            latency: latency
        )
    }
}
