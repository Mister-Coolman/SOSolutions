//
//  FireworksService.swift
//  SOSolutions
//
//  Created by Arjun Rangarajan on 3/4/26.
//

import Foundation
import SwiftUI

struct FireworksService {
    private static let modelName = "accounts/fireworks/models/kimi-k2p6"

    static func analyzeImage(_ image: UIImage) async throws -> [String] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }

        let base64Image = imageData.base64EncodedString()

        let url = URL(string: "https://sosolutions-server-production.up.railway.app/fireworks/chat")!

        // System message: strict role + output format
        let systemPrompt = """
            You are an emergency image analyst for deaf and hard-of-hearing 911 callers. \
            Your only job is to convert an image into exactly 3 numbered emergency descriptions for a dispatcher.

            ABSOLUTE OUTPUT RULES:
            - Your response must begin IMMEDIATELY with "1." — no title, no intro, no meta-commentary, no explanation
            - Write exactly 3 lines total, numbered 1, 2, 3
            - Each line is one self-contained description, 25–30 words
            - Cover ALL critical details: injury type/location/severity/blood loss, hazards, threats to life
            - Each line must reword the same facts differently — not identical, not redundant
            - If you are less than 70% confident about something, use "possibly" — never fabricate
            - Nothing may appear in your response before "1." or after the end of line 3
            """

        // User message: concise task + image
        let userPrompt = """
            Describe every critical emergency detail visible in this image. \
            Include: injury type, body location, severity, estimated blood loss, \
            any environmental hazards, and any other life-threatening conditions.
            """

        let requestBody: [String: Any] = [
            "model": modelName,
            "max_tokens": 300,
            "enable_thinking": false,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": userPrompt
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
            "temperature": 0.3
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        // Log raw response for debugging
        if let raw = String(data: data, encoding: .utf8) {
            print("Fireworks raw response: \(raw.prefix(800))")
        }

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NSError(domain: "FireworksService", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid response from API."])
        }

        do {
            let decoded = try JSONDecoder().decode(FireworksResponse.self, from: data)
            let msg = decoded.choices.first?.message
            let text = msg?.content ?? msg?.reasoning_content ?? ""
            guard !text.isEmpty else {
                throw NSError(domain: "FireworksService", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Empty response content."])
            }
            return parseDescriptions(from: text)
        } catch {
            print("Fireworks decode error: \(error)")
            throw error
        }
    }

    private static func parseDescriptions(from text: String) -> [String] {
        // Strip any preamble lines that don't start with a digit
        let lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Find where the numbered list actually starts
        let numbered = lines.filter { $0.first?.isNumber == true }
        let source = numbered.isEmpty ? lines : numbered

        return source
            .map { $0.replacingOccurrences(of: #"^\d+[.)\s]+\s*"#, with: "",
                                           options: .regularExpression) }
            .filter { !$0.isEmpty }
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
    let content: String?           // null when thinking mode active
    let reasoning_content: String? // fallback
}
