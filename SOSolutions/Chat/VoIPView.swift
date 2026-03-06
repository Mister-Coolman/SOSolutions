//
//  VoIPTestView.swift
//  SOSolutions
//
//  Created for Twilio VoIP Testing
//

import SwiftUI
import Combine
import AVFoundation
import SwiftUI
import TwilioVoice

class TwilioVoiceManager: NSObject, ObservableObject, CallDelegate, NotificationDelegate {

    // MARK: - Published State
    @Published var callStatus: String = "Idle"
    @Published var isConnected: Bool = false
    @Published var isMuted: Bool = false
    @Published var statusColor: Color = .gray

    // Transcription events forwarded to ChatView
    var onTranscriptionUpdate: ((String, Bool) -> Void)?  // (text, isFinal)

    // Speaking state forwarded to ChatView
    var onSpeakingStateChange: ((Bool) -> Void)?  // true = speaking started, false = done

    // MARK: - Private
    private var accessToken: String?
    private var activeCall: Call?
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pingTimer: Timer?

    private var currentCallSid: String?
    private var reconnectAttempt: Int = 0

    // TODO: Replace with your Twilio Function token URL
    private let tokenEndpoint = SecretsHelper.getTokenEndpoint()

    // TODO: Replace with your ngrok URL
    private let serverBase = SecretsHelper.getNgrokURL()

    // MARK: - Token Fetch
    func fetchToken(completion: (() -> Void)? = nil) {
        updateStatus("Fetching token…", color: .orange)
        guard let url = URL(string: tokenEndpoint) else {
            updateStatus("Invalid token URL", color: .red)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                self.updateStatus("Token fetch failed: \(error.localizedDescription)", color: .red)
                return
            }
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let token = json["token"] as? String
            else {
                self.updateStatus("Bad token response", color: .red)
                return
            }
            self.accessToken = token
            self.updateStatus("Ready", color: .green)
            DispatchQueue.main.async { completion?() }
        }.resume()
    }

    // MARK: - Outbound Call
    func makeCall(to number: String) {
        guard let token = accessToken else {
            updateStatus("No token", color: .red)
            return
        }

        let connectOptions = ConnectOptions(accessToken: token) { builder in
            builder.params = ["To": number]
        }

        updateStatus("Calling…", color: .orange)
        activeCall = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
    }

    // MARK: - Hang Up
    func hangUp() {
        activeCall?.disconnect()
        disconnectWebSocket()
    }

    // MARK: - Mute
    func toggleMute() {
        guard let call = activeCall else { return }
        isMuted.toggle()
        call.isMuted = isMuted
    }

    // MARK: - Speak text into the call via Twilio TTS
    func speak(_ text: String) {
        guard let callSid = activeCall?.sid else { return }
        guard let url = URL(string: "\(serverBase)/speak") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "callSid": callSid,
            "text": text
        ])

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error {
                print("Speak error: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - WebSocket (receives transcription events from server)
    private func connectWebSocket(callSid: String) {
        guard let url = URL(string: serverBase.replacingOccurrences(of: "https", with: "wss")) else { return }
        urlSession = URLSession(configuration: .default)
        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()
        startPingTimer()

        // Register this call with the server
        let registerMsg = try? JSONSerialization.data(withJSONObject: [
            "type": "register",
            "callSid": callSid
        ])
        if let data = registerMsg {
            webSocket?.send(.data(data)) { [weak self] error in
                if error == nil {
                    self?.reconnectAttempt = 0
                }
            }
        }

        listenWebSocket()
    }

    private func listenWebSocket() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleWebSocketMessage(text)
                    }
                @unknown default:
                    break
                }
                self.listenWebSocket()
            case .failure(let error):
                print("WebSocket error: \(error.localizedDescription)")
                guard self.isConnected, let sid = self.currentCallSid, !sid.isEmpty else { return }
                self.reconnectAttempt = min(self.reconnectAttempt + 1, 4)
                let delay = pow(2.0, Double(self.reconnectAttempt)) // 2, 4, 8, 16 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, self.isConnected else { return }
                    print("WebSocket dropped, reconnecting… (attempt \(self.reconnectAttempt))")
                    self.connectWebSocket(callSid: sid)
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ text: String) {
        guard
            let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = json["type"] as? String
        else { return }

        if type == "transcription",
           let transcriptionText = json["text"] as? String,
           let event = json["event"] as? String {
            let isFinal = event == "transcription-stopped"
            DispatchQueue.main.async {
                self.onTranscriptionUpdate?(transcriptionText, isFinal)
            }
        }

        if type == "speaking",
           let state = json["state"] as? String {
            let isSpeaking = state == "start"
            DispatchQueue.main.async {
                self.onSpeakingStateChange?(isSpeaking)
            }
            if state == "end" {
                if let sid = self.currentCallSid, !sid.isEmpty {
                    // Force a clean re-register regardless of current socket state
                    self.disconnectWebSocket()
                    self.connectWebSocket(callSid: sid)
                }
            }
        }
    }

    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.webSocket?.sendPing { error in
                if let error {
                    print("WebSocket ping failed: \(error.localizedDescription)")
                    // Force a clean reconnect using cached SID
                    self.disconnectWebSocket()
                    if self.isConnected, let sid = self.currentCallSid, !sid.isEmpty {
                        self.connectWebSocket(callSid: sid)
                    }
                }
            }
        }
        if let pingTimer { RunLoop.main.add(pingTimer, forMode: .common) }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func disconnectWebSocket() {
        stopPingTimer()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    // MARK: - CallDelegate
    func callDidConnect(call: Call) {
        activeCall = call
        updateStatus("Connected", color: .green)
        isConnected = true
        let sid = call.sid
        guard !sid.isEmpty else { return }
        currentCallSid = sid
        reconnectAttempt = 0
        connectWebSocket(callSid: sid)
    }

    func callDidDisconnect(call: Call, error: Error?) {
        isConnected = false
        isMuted = false
        activeCall = nil
        disconnectWebSocket()
        updateStatus(error != nil ? "Disconnected (error)" : "Call ended", color: .gray)
    }

    func callDidFailToConnect(call: Call, error: Error) {
        isConnected = false
        activeCall = nil
        updateStatus("Failed to connect", color: .red)
    }

    // MARK: - NotificationDelegate
    func callInviteReceived(callInvite: CallInvite) {}
    func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {}

    // MARK: - Helpers
    private func updateStatus(_ text: String, color: Color) {
        DispatchQueue.main.async {
            self.callStatus = text
            self.statusColor = color
        }
    }
}


