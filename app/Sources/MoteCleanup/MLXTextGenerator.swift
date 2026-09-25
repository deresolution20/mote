import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

actor MLXTextGenerator {
    static let shared = MLXTextGenerator()

    private let loader = ContainerLoader()

    func generate(prompt: String, maxTokens: Int, temperature: Float) async throws -> String {
        let container = try await loader.loadContainer()
        let parameters = GenerateParameters(maxTokens: maxTokens, temperature: temperature)
        let input = try await container.prepare(input: UserInput(prompt: prompt))
        let stream = try await container.generate(input: input, parameters: parameters)
        var output = ""
        for await item in stream {
            if case .chunk(let chunk) = item {
                output += chunk
            }
        }
        return output
    }
}

private actor ContainerLoader {
    private var containerTask: Task<ModelContainer, Error>?

    func loadContainer() async throws -> ModelContainer {
        if let existingTask = containerTask {
            return try await existingTask.value
        }

        let task = Task {
            try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                configuration: LLMRegistry.qwen2_5_1_5b
            )
        }
        containerTask = task

        do {
            return try await task.value
        } catch {
            containerTask = nil
            throw error
        }
    }
}
