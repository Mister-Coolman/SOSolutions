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

        let prompt = """
            You are an emergency image analyst for deaf and hard-of-hearing 911 callers. \
            Analyze the image and return EXACTLY 3 numbered descriptions for a 911 dispatcher.

            STRICT OUTPUT FORMAT — your entire response must be:
            1. [description]
            2. [description]
            3. [description]

            Begin your response immediately with "1." — no title, no intro, no explanation before it.
            Nothing after line 3.

            Rules for each description (25–30 words each):
            - Cover ALL critical details visible: injury type, body location, severity, blood loss, hazards, threats to life
            - Each line must reword the same facts differently — varied phrasing, same information
            - If less than 70% confident about something, write "possibly" — never fabricate details
            """

        let requestBody: [String: Any] = [
            "model": modelName,
            "max_tokens": 300,
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
