import SwiftUI
import RegexBuilder
import Foundation
import PhotosUI

//struct ContentView: View {
//    @State var llm = LLMEvaluator()
//    @State private var multiLineText = ""
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Status bar with progress indicator
//            VStack(spacing: 0) {
//                // Progress bar
//                if isModelDownloading() {
//                    // Red progress bar when downloading
//                    ProgressView(value: getDownloadProgress(), total: 100)
//                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
//                        .frame(height: 4)
//                } else if isModelLoaded() {
//                    // Green bar when model is loaded
//                    Rectangle()
//                        .fill(Color.green)
//                        .frame(height: 4)
//                } else {
//                    // Empty space when neither downloading nor loaded
//                    Rectangle()
//                        .fill(Color.clear)
//                        .frame(height: 4)
//                }
//            }
//            
//            // Chat messages area
//            ScrollViewReader { proxy in
//                Text("mlxchat")
//                    .font(.largeTitle)
//                    .padding(.vertical, 10)
//                    .frame(maxWidth: .infinity, alignment: .center)
//                
//                ScrollView {
//                    VStack {
//                        Text(.init(llm.output))
//                            .frame(maxWidth: .infinity, alignment: .leading)
//                            .padding(.horizontal)
//                            .padding(.top, 10)
//                        
//                        // Invisible view at the bottom for scrolling
//                        Color.clear
//                            .frame(height: 1)
//                            .id("bottomID")
//                    }
//                }
//                .onChange(of: llm.output) {
//                    withAnimation {
//                        proxy.scrollTo("bottomID", anchor: .bottom)
//                    }
//                }
//                .onAppear {
//                    // Scroll to bottom when view appears
//                    proxy.scrollTo("bottomID", anchor: .bottom)
//                }
//            }
//            .frame(maxWidth: .infinity)
//            .background(Color(.systemBackground))
//            
//            Divider()
//                 
//            // Input area
//            HStack(alignment: .bottom) {
//                // Text editor
//                ZStack(alignment: .leading) {
//                    TextEditor(text: $multiLineText)
//                        .padding(4)
//                        .cornerRadius(10)
//                        .frame(minHeight: 40, maxHeight: 120)
//                }
//                
//                // Send button
//                VStack(spacing: 8) {
//                    Button(action: sendMessage) {
//                        Image(systemName: "arrow.up.circle.fill")
//                            .resizable()
//                            .frame(width: 32, height: 32)
//                            .foregroundColor(.blue)
//                    }
//                    
//                    // Clear button
//                    Button(action: clearMessages) {
//                        Image(systemName: "trash.circle.fill")
//                            .resizable()
//                            .frame(width: 32, height: 32)
//                            .foregroundColor(.red)
//                    }
//                }
//            }
//            .padding()
//        }
//    }
//    
//    private func sendMessage() {
//        Task {
//            await llm.generate(prompt: multiLineText, type: 0)
//        }
//    }
//    
//    private func clearMessages() {
//
//    }
//    
//    // Helper function to check if model is currently downloading
//    private func isModelDownloading() -> Bool {
//        return llm.modelInfo.contains("Downloading")
//    }
//    
//    // Helper function to check if model is loaded
//    private func isModelLoaded() -> Bool {
//        return llm.modelInfo.contains("Loaded")
//    }
//    
//    // Helper function to extract download progress percentage
//    private func getDownloadProgress() -> Double {
//        let regex = Regex {
//            "Downloading"
//            ZeroOrMore(.any, .reluctant)
//            ": "
//            Capture {
//                OneOrMore(.digit)
//            }
//            "%"
//        }
//        
//        if let match = llm.modelInfo.firstMatch(of: regex) {
//            if let percentage = Double(match.1) {
//                return percentage
//            }
//        }
//        return 0
//    }
//}

// MARK: - Camera Picker (UIImagePickerController wrapper)

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - ContentView

struct ContentView: View {

    @State private var selectedItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var descriptions: [String] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?

    var body: some View {
        NavigationView {
            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("No image selected.")
                }

                // Camera button
                Button {
                    showCamera = true
                } label: {
                    Label("Take Picture", systemImage: "camera.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundStyle(Color.white)
                        .cornerRadius(12)
                }

                // Photo library picker
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    preferredItemEncoding: .automatic,
                    photoLibrary: .shared()
                ) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundStyle(Color.primary)
                        .cornerRadius(12)
                }

                if isLoading {
                    ProgressView("Analyzing image...")
                        .padding()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(Color.red)
                }

                if !descriptions.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Emergency Descriptions")
                                .font(.headline)
                            ForEach(descriptions, id: \.self) { description in
                                Text(description)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle(Text("Emergency Image Analyzer"))
        }
        // Handle photo library selection
        .onChange(of: selectedItem) { newValue in
            Task {
                await loadImage(from: newValue)
            }
        }
        // Handle camera capture
        .onChange(of: cameraImage) { newImage in
            guard let newImage else { return }
            image = newImage
            Task { await analyze(newImage) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $cameraImage)
                .ignoresSafeArea()
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                image = uiImage
                await analyze(uiImage)
            }
        } catch {
            errorMessage = "Failed to load image."
        }
    }

    private func analyze(_ uiImage: UIImage) async {
        isLoading = true
        errorMessage = nil
        descriptions = []

        do {
            descriptions = try await FireworksService.analyzeImage(uiImage)
        } catch {
            errorMessage = "Failed to analyze image."
        }

        isLoading = false
    }
}
