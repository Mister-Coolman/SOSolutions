//
//  ChatView.swift
//  SOSolutions
//

import SwiftUI
import TwilioVoice

struct Message: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool        // true = you (sent via TTS), false = callee (transcribed)
}

struct ChatView: View {
    @Binding var inChat: Bool
    @Binding var callNumber: String

    @StateObject private var voiceManager = TwilioVoiceManager()

    @State private var messages: [Message] = []
    @State private var inputText: String = ""

    // Transcription accumulation
    @State private var currentTranscript: String = ""
    @State private var silenceTimer: Timer? = nil
    @State private var isSpeaking: Bool = false

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

                    Button(action: {
                        voiceManager.toggleMute()
                    }) {
                        Image(systemName: voiceManager.isMuted ? "mic.slash.fill" : "mic.fill")
                            .foregroundStyle(Color.white)
                            .padding()
                            .background(voiceManager.isMuted ? Color.red : Color.blue)
                            .clipShape(Circle())
                    }
                    .disabled(!voiceManager.isConnected)
                }
                .padding()
                .overlay(
                    Rectangle()
                        .fill(voiceManager.statusColor)
                        .frame(height: 4),
                    alignment: .bottom
                )

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
                            ForEach(messages) { message in
                                HStack {
                                    if message.isUser {
                                        Spacer()
                                        Text(message.text)
                                            .padding(10)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(16)
                                    } else {
                                        Text(.init(message.text))
                                            .padding(10)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(16)
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
                        .disabled(!voiceManager.isConnected || isSpeaking)

                    Button("Send") {
                        sendMessage()
                    }
                    .disabled(inputText.isEmpty || !voiceManager.isConnected || isSpeaking)
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
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""
        messages.append(Message(text: text, isUser: true))
        voiceManager.speak(text)
    }
}
