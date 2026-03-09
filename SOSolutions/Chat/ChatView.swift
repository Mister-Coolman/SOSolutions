//
//  ChatView.swift
//  SOSolutions
//

import SwiftUI
import TwilioVoice
import PhotosUI

struct Message: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var simpleText: String? = nil
    let isUser: Bool        // true = you (sent via TTS), false = callee (transcribed)
    var showSimple: Bool = false
}

struct ChatView: View {
    @Binding var inChat: Bool
    @Binding var callNumber: String

    @StateObject private var voiceManager = TwilioVoiceManager()

    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    
    // For camera
    @State private var image: UIImage?
    @State private var descriptions: [String] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showCamera: Bool = false
    @State private var cameraImage: UIImage?
    
    // Transcription accumulation
    @State private var currentTranscript: String = ""
    @State private var silenceTimer: Timer? = nil
    @State private var isSpeaking: Bool = false

    // LLM Stuff
    @State var llm = LLMEvaluator()
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button {
                        withAnimation() {
                            inChat = false
                        }
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 35))
                            .foregroundColor(.white)
                            .padding(25)
                            .background(Color.red)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button {
                        showCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(Color.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
                            .font(.system(size: 35))
                    }
//                    .disabled(!voiceManager.isConnected)
                }
                .padding()
                .overlay(
                    Rectangle()
                        .fill(voiceManager.statusColor)
                        .frame(height: 4),
                    alignment: .bottom
                )
                .onChange(of: cameraImage) { oldImage, newImage in
                    guard let newImage else { return }
                    image = newImage
                    Task { await analyze(newImage) }
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraPicker(image: $cameraImage)
                        .ignoresSafeArea()
                }

                // MARK: - Speaking Banner
                if isSpeaking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Speaking to caller…")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach($messages) { $message in
                                HStack {
                                    if message.isUser {
                                        Spacer()
                                        Text(message.text)
                                            .padding(10)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(16)
                                    } else {
                                        Text((message.showSimple ? message.simpleText : .init(message.text)) ?? .init(message.text))
                                            .padding(10)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(16)
                                            .onTapGesture {
                                                handleMessageTap($message)
                                            }
                                        Spacer()
                                    }
                                }
                            }

                            // Live transcription preview bubble
                            if !currentTranscript.isEmpty {
                                HStack {
                                    Text(readTranscript(rawTranscript: currentTranscript))
                                        .padding(10)
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(16)
                                        .italic()
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("bottomID")
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        withAnimation {
                            proxy.scrollTo("bottomID", anchor: .bottom)
                        }
                    }
                    .onChange(of: currentTranscript) {
                        withAnimation {
                            proxy.scrollTo("bottomID", anchor: .bottom)
                        }
                    }
                }

                HStack {
                    TextField("Message", text: $inputText)
                        .textFieldStyle(.roundedBorder)
//                        .disabled(!voiceManager.isConnected || isSpeaking)

                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(inputText.isEmpty)
//                    .disabled(inputText.isEmpty || !voiceManager.isConnected || isSpeaking)
                }
                .padding()
            }
        }
        .onAppear {
            startCall()
        }
        .animation(.easeInOut(duration: 0.2), value: isSpeaking)
    }

    // MARK: - Start Call
    private func startCall() {
        voiceManager.fetchToken {
            voiceManager.makeCall(to: callNumber)
        }

        voiceManager.onTranscriptionUpdate = { text, isFinal in
            currentTranscript = text

            silenceTimer?.invalidate()
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                commitTranscript()
            }

            if isFinal {
                silenceTimer?.invalidate()
                commitTranscript()
            }
        }

        voiceManager.onSpeakingStateChange = { speaking in
            withAnimation(.easeInOut(duration: 0.2)) {
                isSpeaking = speaking
            }
        }
    }

    // MARK: - Commit transcript as a new message bubble
    private func commitTranscript() {
        guard let text = parseTranscript(currentTranscript),
              !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            currentTranscript = ""
            return
        }
        messages.append(Message(text: text, isUser: false))
        currentTranscript = ""
    }

    private func readTranscript(rawTranscript: String) -> String {
        return parseTranscript(rawTranscript) ?? ""
    }

    private func parseTranscript(_ raw: String) -> String? {
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let transcript = json["transcript"] as? String {
            return transcript
        }
        return raw.isEmpty ? nil : raw
    }

    // MARK: - Send Message (TTS via Twilio)
    private func sendMessage() {
//        guard !inputText.isEmpty else { return }
//        let text = inputText
//        inputText = ""
//        messages.append(Message(text: text, isUser: true))
//        voiceManager.speak(text)
        messages.append(Message(text: inputText, isUser: true))
        messages.append(Message(text: "John, I need you to stay calm. We are sending an ambulance to your location. Can you tell me if the person is conscious and breathing?", isUser: false))
        inputText = ""
    }
    
    // Send crap to Fireworks
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
    
    private func handleMessageTap(_ message: Binding<Message>) {
        if (message.simpleText.wrappedValue != nil) {
            Task {
                await llm.generate(prompt: message.text.wrappedValue, type: 0)
            }
            message.simpleText.wrappedValue = llm.output
        }
        message.showSimple.wrappedValue.toggle()
    }
}
