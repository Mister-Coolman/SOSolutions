//
//  SecretsHelper.swift
//  SOSolutions
//
//  Created by Arjun Rangarajan on 3/5/26.
//

import Foundation

struct SecretsHelper {
    static func getPhoneNumbers() -> [String] {
        guard let numbersString = Bundle.main.object(forInfoDictionaryKey: "PHONE_NUMBERS") as? String else {
            print("PHONE_NUMBERS not found in Info.plist")
            return []
        }
        
        // Split by comma and trim whitespace/newlines
        let numbers = numbersString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } // Remove empty entries
        
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
