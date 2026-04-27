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
        
        let numbers = numbersString
            .components(separatedBy: ",")
            .map { rawNumber in
                var number = rawNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove spaces, dashes, parentheses, etc.
                number = number.filter { $0.isNumber || $0 == "+" }
                
                // If the + was stripped but the number starts with 1 and has 11 digits,
                // restore it as a US E.164 number.
                if !number.hasPrefix("+") {
                    if number.count == 11 && number.hasPrefix("1") {
                        number = "+" + number
                    } else if number.count == 10 {
                        number = "+1" + number
                    }
                }
                
                return number
            }
            .filter { number in
                let pattern = #"^\+[1-9]\d{7,14}$"#
                return number.range(of: pattern, options: .regularExpression) != nil
            }
        
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
