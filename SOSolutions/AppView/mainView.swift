//
//  mainView.swift
//  SOSolutions
//
//  Created by Dee Hay on 2/3/26.
//

import SwiftUI

struct mainView: View {
    
    
    let username: String
    @Binding var inChat: Bool
    @State private var showYesNo: Bool = false
    @State private var showMedicalHistory: Bool = false
    @State private var selectedNumber: String = ""
    @Binding var callNumber: String

    let phoneNumbers = SecretsHelper.getPhoneNumbers()
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar - Name / Medical History Buttons
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WELCOME")
                        .font(.largeTitle)
                    Text(username.uppercased())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button {
                    showMedicalHistory = true
                } label: {
                    Image(systemName: "cross.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                }
            }
            .padding()
            .overlay(
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(Color.blue),
                alignment: .bottom
            )
            // end first hstack
            
            Spacer()
            
            // Big green phone button
            Button {
                withAnimation {
                    showYesNo.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 320, height: 320)
                    
                    Image(systemName: "phone.fill")
                        .font(.system(size: 180))
                        .foregroundStyle(Color.white)
                }
            }
            
            // YES/NO Buttons
            if showYesNo {
                HStack(spacing: 32) {
                    Button {
                        withAnimation(){
                            inChat = true
                        }
                    } label: {
                        Text("YES")
                            .fontWeight(.bold)
                            .font(.title)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Color.green)
                            .foregroundStyle(Color.black)
                            .cornerRadius(32)
                    }
                    
                    Button {
                        withAnimation {
                            showYesNo.toggle()
                        }
                    } label: {
                        Text("NO")
                            .fontWeight(.bold)
                            .font(.title)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(Color.red)
                            .foregroundStyle(Color.black)
                            .cornerRadius(32)
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)
                .transition(.opacity)
            }
            
            Spacer()
            
            // Language Selectorthing
            HStack {
                Text("Select Number to Call:")
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker("Phone Number", selection: $callNumber) {
                    ForEach(phoneNumbers, id: \.self) {
                        Text($0)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(20)
            }
            .padding()
            
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(Color.blue)
        }
        .sheet(isPresented: ($showMedicalHistory)) {
            MedicalHistoryView()
        }
    }
}
