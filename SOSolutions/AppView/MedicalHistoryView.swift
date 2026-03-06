import SwiftUI
// =====================================================
// SINGLE FILE MEDICAL HISTORY SYSTEM
// - One user only
// - JSON saved locally
// - ALSO syncs to iCloud when signed in
// - Dynamic lists
// - Swipe to delete
// - Edit inline
// =====================================================
// MARK: - DATA MODELS
struct MedicalProfile: Codable, Equatable {
    var name: String = ""
    var dateOfBirth: Date = Date()
    
    var addresses: [Address] = []
    var medications: [Medication] = []
    var allergies: [String] = []
    var illnesses: [String] = []
}
struct Address: Codable, Identifiable, Equatable {
    var id = UUID()
    var street: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
}
struct Medication: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    var dosage: String = ""
    var frequency: String = ""
}
// MARK: - MAIN VIEW
struct MedicalHistoryView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var profile = MedicalProfile()
    
    private let cloudStore = NSUbiquitousKeyValueStore.default
    
    var body: some View {
        NavigationStack {
            Form {
                
                // MARK: BASIC INFO
                Section("Basic Information") {
                    TextField("Full Name", text: $profile.name)
                    DatePicker("Date of Birth", selection: $profile.dateOfBirth, displayedComponents: .date)
                }
                
                
                // MARK: ADDRESSES
                Section {
                    ForEach($profile.addresses) { $address in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Street", text: $address.street)
                            TextField("City", text: $address.city)
                            TextField("State", text: $address.state)
                            TextField("ZIP", text: $address.zip)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        profile.addresses.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Address") {
                        profile.addresses.append(Address())
                    }
                } header: {
                    Text("Addresses")
                }
                
                
                // MARK: MEDICATIONS
                Section {
                    ForEach($profile.medications) { $med in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Medication Name", text: $med.name)
                            TextField("Dosage", text: $med.dosage)
                            TextField("Frequency", text: $med.frequency)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        profile.medications.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Medication") {
                        profile.medications.append(Medication())
                    }
                } header: {
                    Text("Medications")
                }
                
                
                // MARK: ALLERGIES
                Section {
                    ForEach(profile.allergies.indices, id: \.self) { i in
                        TextField("Allergy", text: $profile.allergies[i])
                    }
                    .onDelete { indexSet in
                        profile.allergies.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Allergy") {
                        profile.allergies.append("")
                    }
                } header: {
                    Text("Allergies")
                }
                
                
                // MARK: ILLNESSES
                Section {
                    ForEach(profile.illnesses.indices, id: \.self) { i in
                        TextField("Illness", text: $profile.illnesses[i])
                    }
                    .onDelete { indexSet in
                        profile.illnesses.remove(atOffsets: indexSet)
                    }
                    
                    Button("Add Illness") {
                        profile.illnesses.append("")
                    }
                } header: {
                    Text("Past / Current Illnesses")
                }
            }
            .navigationTitle("Medical History")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .tint(.blue)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadProfile()
            }
            
            // iOS 17 change observer
            .onChange(of: profile) { _, _ in
                saveProfile()
            }
        }
    }
    
    
    // =====================================================
    // MARK: - STORAGE HELPERS
    // =====================================================
    
    /// Always save locally (for preview + testing)
    private func localFileURL() -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("medicalProfile.json")
    }
    
    /// If signed in, use Apple user ID as iCloud key
//    private func cloudKey() -> String? {
//        guard let userID = KeychainSrvc.load(keychainKeys.appleUserID) else {
//            return nil
//        }
//        return "medicalProfile_\(userID)"
//    }
    
    
    // =====================================================
    // MARK: - SAVE
    // =====================================================
    
    private func saveProfile() {
        do {
            let data = try JSONEncoder().encode(profile)
            
            // ALWAYS SAVE LOCAL (testing + offline)
            try data.write(to: localFileURL(), options: [.atomic])
            
            // ALSO SAVE TO ICLOUD IF SIGNED IN
//            if let key = cloudKey() {
//                cloudStore.set(data, forKey: key)
//                cloudStore.synchronize()
//            }
            
        } catch {
            print("SAVE ERROR:", error)
        }
    }
    
    
    // =====================================================
    // MARK: - LOAD
    // =====================================================
    
    private func loadProfile() {
        do {
            
//            // TRY ICLOUD FIRST (if signed in)
//            if let key = cloudKey(),
//               let data = cloudStore.data(forKey: key) {
//                profile = try JSONDecoder().decode(MedicalProfile.self, from: data)
//                return
//            }
            
            // FALL BACK TO LOCAL FILE
            let data = try Data(contentsOf: localFileURL())
            profile = try JSONDecoder().decode(MedicalProfile.self, from: data)
            
        } catch {
            print("No saved profile yet")
        }
    }
}
