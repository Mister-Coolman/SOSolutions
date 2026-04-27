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
    @State private var selectedNumberOption: String = ""
    @State private var customPhoneNumber: String = ""
    @Binding var callNumber: String
    
    @FocusState private var isCustomNumberFocused: Bool

    let phoneNumbers = SecretsHelper.getPhoneNumbers()
    private let customOption = "Custom Number"
    private let customFieldID = "customPhoneNumberField"
    
    private var allNumberOptions: [String] {
        phoneNumbers + [customOption]
    }
    
    private var isUsingCustomNumber: Bool {
        selectedNumberOption == customOption
    }
    
    private var effectiveCallNumber: String {
        isUsingCustomNumber ? customPhoneNumber : selectedNumberOption
    }
    
    private var normalizedCallNumber: String {
        effectiveCallNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isValidCallNumber: Bool {
        let pattern = #"^\+[1-9]\d{7,14}$"#
        return normalizedCallNumber.range(of: pattern, options: .regularExpression) != nil
    }
    
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
                        callNumber = normalizedCallNumber
                        isCustomNumberFocused = false
                        
                        withAnimation {
                            inChat = true
                        }
                    } label: {
                        Text("YES")
                            .fontWeight(.bold)
                            .font(.title)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .background(isValidCallNumber ? Color.green : Color.gray)
                            .foregroundStyle(Color.black)
                            .cornerRadius(32)
                    }
                    .disabled(!isValidCallNumber)
                    
                    Button {
                        isCustomNumberFocused = false
                        
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
            
            // Number Selector
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Select Number to Call:")
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Picker("Phone Number", selection: $selectedNumberOption) {
                                ForEach(allNumberOptions, id: \.self) { number in
                                    Text(number).tag(number)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(20)
                        }
                        
                        if isUsingCustomNumber {
                            TextField("Enter number, e.g. +15185551234", text: $customPhoneNumber)
                                .id(customFieldID)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                                .font(.title3)
                                .foregroundStyle(Color.primary)
                                .tint(Color.blue)
                                .padding()
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                                )
                                .cornerRadius(16)
                                .focused($isCustomNumberFocused)
                            
                            if !customPhoneNumber.isEmpty && !isValidCallNumber {
                                Text("Use full format like +15185551234")
                                    .font(.caption)
                                    .foregroundStyle(Color.red)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, isCustomNumberFocused ? 260 : 0)
                }
                .frame(maxHeight: isUsingCustomNumber ? 190 : 85)
                .scrollIndicators(.hidden)
                .onChange(of: isCustomNumberFocused) { _, focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                proxy.scrollTo(customFieldID, anchor: .center)
                            }
                        }
                    }
                }
            }
            
            Rectangle()
                .frame(height: 2)
                .foregroundStyle(Color.blue)
        }
        .onAppear {
            if selectedNumberOption.isEmpty {
                if callNumber.isEmpty {
                    selectedNumberOption = phoneNumbers.first ?? customOption
                    callNumber = phoneNumbers.first ?? ""
                } else if phoneNumbers.contains(callNumber) {
                    selectedNumberOption = callNumber
                } else {
                    selectedNumberOption = customOption
                    customPhoneNumber = callNumber
                }
            }
        }
        .onChange(of: selectedNumberOption) { _, newValue in
            if newValue == customOption {
                customPhoneNumber = ""
                callNumber = ""
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isCustomNumberFocused = true
                }
            } else {
                isCustomNumberFocused = false
                callNumber = newValue
            }
        }
        .onChange(of: customPhoneNumber) { _, newValue in
            if isUsingCustomNumber {
                callNumber = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isCustomNumberFocused = false
                }
            }
        }
        .sheet(isPresented: $showMedicalHistory) {
            MedicalHistoryView()
        }
    }
}
