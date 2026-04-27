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

        let url = URL(string: "https://sosolutions-server-production.up.railway.app/fireworks/chat")!
        
        let prompt = """
            You are responsible for conveying critical information to a 911 dispatcher. You are facilitating communication between members of the deaf community and emergency services. When a user takes an image of their surroundings or other critical information pertaining to the situation, your role is to translate the visual information into text in a manner that is relevant, precise, and does not lose meaning.

            Important rules to follow:

            Focus and understand the image taken by the user, and record ALL critical information pertaining to it (for example, if the image taken is of a laceration, critical information to record should be approximate laceration depth, height, placement, blood-loss level, etc.)

            If unsure (<70% confident) about the identity of an object, do not lie or hallucinate, say you are unsure. The goal of this prompt is to ensure the safety of the user in life-or-death scenarios.

            Return ONLY a numbered list of three descriptions that follow the guidelines listed above exactly. Each description should adhere to all of the guidelines, but they must use different wording. Do not return three identical statements. Do not return statements that do not contain all critical medical, environmental, and social information that pose a threat to the user.
            
            Limit each explanation to 25-30 words. The most important thing is to ensure that all information returned is accurate. Do NOT lie at all. 
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
