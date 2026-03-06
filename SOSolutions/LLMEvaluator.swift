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

        let systemPrompt: String = type == 1 ? "You are a helpful assistant. Act like a helpful chatbot, answering the user's queries with as much accuracy as possible." : "Rewrite the message so that a 4th grade student can understand it. STRICT RULES: Keep every fact exactly the same. Do not change meaning. Do not add or remove information. Do not summarize. Do not explain extra details. Use simple words. Keep numbers, names, and addresses unchanged. Output ONLY the rewritten message."
        
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
