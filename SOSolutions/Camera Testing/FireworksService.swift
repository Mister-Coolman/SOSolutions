//
//  FireworksService.swift
//  SOSolutions
//
//  Created by Arjun Rangarajan on 3/4/26.
//

import Foundation
import SwiftUI

struct FireworksService {
    private static let modelName = "accounts/fireworks/models/qwen3-vl-30b-a3b-instruct"
    
    static func analyzeImage(_ image: UIImage) async throws -> [String] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }
        
        let base64Image = imageData.base64EncodedString()

        let url = URL(string: "\(SecretsHelper.getNgrokURL())/fireworks/chat")!
        
        let prompt = """
            Analyze this image and generate EXACTLY 3 concise descriptions helpful for 911 emergency
            
            Focus on:
            - Visible injuries
            - Hazards (fire, smoke, weapons, crash damage)
            - Immediate medical emergency
            - Environmental risks
            - Location clues
            
            Each description must:
            - Be 1-2 sentences
            - Be factual and objective
            - Avoid speculation and hallucinations
            - Be clearly actionable
            
            Return ONLY a numbered list of 3 items.
            """
        
        let requestBody: [String: Any] = [
            "model": modelName,
            "max_tokens": 400,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "temperature": 0.5
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NSError(domain: "FireworksService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from API."])
        }
        
        let decoded = try JSONDecoder().decode(FireworksResponse.self, from: data)
        
        let text = decoded.choices.first?.message.content ?? "No text available."
        
        return parseDescriptions(from: text)
    }
    
    private static func parseDescriptions(from text: String) -> [String] {
        text
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map {
                $0.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
            }
            .prefix(3)
            .map { String($0) }
    }
}


struct FireworksResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Msg
}

struct Msg: Codable {
    let content: String
}
