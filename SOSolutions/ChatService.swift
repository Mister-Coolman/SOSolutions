//
//  ChatService.swift
//  SOSolutions
//
//  Created by Dee Hay on 2/8/26.
//

import Foundation

final class ChatService {
    var onReceive: ((String) -> Void)?
    var llm = LLMEvaluator()

    func send(_ text: String, type: Int) {
        Task {
            await llm.generate(prompt: text, type: type)
        }
    }
    
    func getLLMOutput() -> String {
        return llm.output
    }
    
    func getModelInfo() -> String {
        return llm.modelInfo
    }
}
