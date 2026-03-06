//
//  rootView.swift
//  SOSolutions
//
//  Created by Dee Hay on 2/3/26.
//

import SwiftUI

struct rootView: View {
    @State private var isSignedIn = true
    @State private var username = "Dee Hay"
    @State private var inChat = false
    @State private var callNumber: String = ""
    
    var body: some View {
        Group {
            if !isSignedIn {
                // SignInView(isSignedIn: $isSignedIn, username: $username)
            } else if inChat {
                ChatView(inChat: $inChat, callNumber: $callNumber)
            } else {
                mainView(username: username, inChat: $inChat, callNumber: $callNumber)
            }
        }
        .onAppear {
           //  checkForExistingUser()
        }
    }
    
//    private func checkForExistingUser() {
//        if let storedUserID = KeychainSrvc.load(keychainKeys.appleUserID) {
//            username = KeychainSrvc.load(keychainKeys.fullName) ?? "User"
//            isSignedIn = true
//            print("Returning user: \(storedUserID)")
//        }
//    }
}
