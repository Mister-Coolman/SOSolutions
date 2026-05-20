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
    @State private var showContactPicker = false

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
        SecretsHelper.normalizeToE164(effectiveCallNumber)
            ?? effectiveCallNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValidCallNumber: Bool {
        SecretsHelper.normalizeToE164(effectiveCallNumber) != nil
    }

    // True when the field has valid content that differs from its E.164 form —
    // i.e. the user typed "5185551234" and we'll convert it to "+15185551234".
    private var needsNormalizationPreview: Bool {
        isUsingCustomNumber && isValidCallNumber && customPhoneNumber != normalizedCallNumber
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
            
            // Number Selector — chips
            VStack(alignment: .leading, spacing: 14) {
                Text("Call number")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(allNumberOptions, id: \.self) { option in
                            let isSelected = selectedNumberOption == option
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedNumberOption = option
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if option == customOption {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    Text(option == customOption ? "Custom" : option)
                                        .font(.system(size: 15, weight: .medium))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        // Contacts picker chip
                        Button {
                            showContactPicker = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Contacts")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }

                if isUsingCustomNumber {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("e.g. +15185551234", text: $customPhoneNumber)
                            .id(customFieldID)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .font(.title3)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        !customPhoneNumber.isEmpty && !isValidCallNumber
                                            ? Color.red.opacity(0.6)
                                            : Color.gray.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                            .focused($isCustomNumberFocused)

                        if !customPhoneNumber.isEmpty && !isValidCallNumber {
                            Text("Enter a valid phone number")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        } else if needsNormalizationPreview {
                            Text("Will dial: \(normalizedCallNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.bottom, 16)
            
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
                    if let normalized = SecretsHelper.normalizeToE164(customPhoneNumber) {
                        customPhoneNumber = normalized
                    }
                    isCustomNumberFocused = false
                }
            }
        }
        .background(
            ContactPickerRepresentable(isPresented: $showContactPicker) { number in
                customPhoneNumber = number
                selectedNumberOption = customOption
            }
            .frame(width: 0, height: 0)
        )
        .sheet(isPresented: $showMedicalHistory) {
            MedicalHistoryView()
        }
    }
}
