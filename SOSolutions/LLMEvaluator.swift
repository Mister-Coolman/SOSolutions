//
//  LLMEvaluator.swift
//  SOSolutions
//
//  Created by Arjun Rangarajan on 2/10/26.
//

import SwiftUI
import MLX
import MLXLMCommon
import MLXLLM
import MLXRandom
import Tokenizers

@Observable
@MainActor
class LLMEvaluator {

    var running = false
    var output = ""
    var modelInfo = ""
    let modelConfiguration = LLMRegistry.qwen2_5_1_5b
    let generateParameters = GenerateParameters(temperature: 0.6)
    let maxTokens = 512
    let displayEveryNTokens = 4

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    var loadState = LoadState.idle

    func load() async throws -> ModelContainer {
        switch loadState {
        case .idle:

            let modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) {
                [modelConfiguration] progress in
                Task { @MainActor in
                    self.modelInfo =
                        "Downloading \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                }
            }
            let numParams = await modelContainer.perform { context in
                context.model.numParameters()
            }

            self.modelInfo =
                "Loaded \(modelConfiguration.id).  Weights: \(numParams / (1024*1024))M"
            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    func generate(prompt: String, type: Int) async {
        guard !running else { return }
        
        running = true
        self.output = ""

        let systemPrompt: String = """
            You will simplify 911 dispatcher messages so that they are clear and easy to read (about 4th grade level, 740L–940L).
            Goal:
            Make the message easier to understand without losing any important meaning.

            Rules:

            Keep all critical details (medical, safety, timing, instructions).


            Do not change meaning or remove important information.


            If a word is already clear and precise, keep it.


            Only simplify when it is safe to do so.


            Use common, everyday words (example: “conscious” → “awake”).


            Keep sentences short and direct (one idea per sentence if possible).


            Keep the tone calm and clear.


            Do not add new information.


            How to process:

            Go part by part.


            Simplify only the parts that need it.


            Leave the rest unchanged.


            Output:

            Return only the simplified message.


            Do not explain your changes.


            Example:
            Input: “Check if the patient is conscious and breathing.”
            Output: “Check if the person is awake and breathing.”
        """
        do {
            let modelContainer = try await load()
            MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))
            let result = try await modelContainer.perform { context in
                let input = try await context.processor.prepare(
                    input: .init(
                        messages: [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user", "content": prompt],
                        ]))
                return try MLXLMCommon.generate(
                    input: input, parameters: generateParameters, context: context
                ) { tokens in
                    // Show the text in the view as it generates
                    if tokens.count % displayEveryNTokens == 0 {
                        let text = context.tokenizer.decode(tokens: tokens)
                        Task { @MainActor in
                            self.output = text
                        }
                    }
                    if tokens.count >= maxTokens {
                        return .stop
                    } else {
                        return .more
                    }
                }
            }

            if result.output != self.output {
                self.output = result.output
            }

        } catch {
            output = "Failed: \(error)"
        }

        running = false
    }
}
