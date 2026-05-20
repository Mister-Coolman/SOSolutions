//
//  SecretsHelper.swift
//  SOSolutions
//
//  Created by Arjun Rangarajan on 3/5/26.
//

import Foundation

struct SecretsHelper {

    // Converts any common phone number format to E.164 (e.g. "(518) 555-1234" → "+15185551234").
    // Returns nil if the result isn't a plausible E.164 number.
    static func normalizeToE164(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPlus = trimmed.hasPrefix("+")
        let digits = trimmed.filter { $0.isNumber }

        var candidate: String
        if hasPlus {
            candidate = "+" + digits
        } else if digits.count == 10 {
            candidate = "+1" + digits          // assume US
        } else if digits.count == 11 && digits.hasPrefix("1") {
            candidate = "+" + digits           // US with country code
        } else {
            candidate = digits                 // leave bare for validation
        }

        let pattern = #"^\+[1-9]\d{7,14}$"#
        guard candidate.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }
        return candidate
    }

    static func getPhoneNumbers() -> [String] {
        guard let numbersString = Bundle.main.object(forInfoDictionaryKey: "PHONE_NUMBERS") as? String else {
            print("PHONE_NUMBERS not found in Info.plist")
            return []
        }
        
        let numbers = numbersString
            .components(separatedBy: ",")
            .compactMap { normalizeToE164($0) }
        
        return numbers
    }
    static func getArray(for key: String) -> [String] {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            print("⚠️ Key \(key) not found in Info.plist")
            return []
        }
        return value
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    static func getTokenEndpoint() -> String {
        guard let tokenEndpoint = Bundle.main.object(forInfoDictionaryKey: "TOKEN_ENDPOINT") as? String else {
            print("TOKEN_ENDPOINT not found in Info.plist")
            return ""
        }
        return tokenEndpoint
    }
    
    static func getNgrokURL() -> String {
        guard let NGROK = Bundle.main.object(forInfoDictionaryKey: "NGROK_URL") as? String else {
            print("NGROK_URL not found in Info.plist")
            return ""
        }
        return NGROK
    }
}
