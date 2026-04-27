import SwiftUI
import Combine
import AVFoundation
import TwilioVoice

final class TwilioVoiceManager: NSObject, ObservableObject, CallDelegate, NotificationDelegate {

    // MARK: - Published State
    @Published var callStatus: String = "Idle"
    @Published var isConnected: Bool = false
    @Published var isMuted: Bool = false
    @Published var statusColor: Color = .gray

    // MARK: - ChatView compatibility callbacks
    // ChatView expects: (text, isFinal)
    var onTranscriptionUpdate: ((String, Bool) -> Void)?
    var onSpeakingStateChange: ((Bool) -> Void)?

    // MARK: - Private state
    private var accessToken: String?
    private var activeCall: Call?
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pingTimer: Timer?

    private var reconnectAttempt: Int = 0
    private var manuallyClosedSocket = false

    private var currentSessionId: String?
    private var pendingPhoneNumber: String?
    private var identity: String?

    // MARK: - Server configuration
    // Replace with your real server base URL
    private let serverBase = "https://sosolutions-server-production.up.railway.app"

    private var tokenEndpoint: String { "\(serverBase)/token" }
    private var startSessionEndpoint: String { "\(serverBase)/start-session" }
    private var speakEndpoint: String { "\(serverBase)/speak" }

    // MARK: - Token Fetch
    func fetchToken(completion: (() -> Void)? = nil) {
        updateStatus("Fetching token…", color: .orange)

        guard var components = URLComponents(string: tokenEndpoint) else {
            updateStatus("Invalid token URL", color: .red)
            return
        }

        let requestedIdentity = "ios-\(UUID().uuidString.prefix(8))"
        components.queryItems = [
            URLQueryItem(name: "identity", value: requestedIdentity)
        ]

        guard let url = components.url else {
            updateStatus("Invalid token request", color: .red)
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
            self.identity = json["identity"] as? String
            self.updateStatus("Ready", color: .green)

            DispatchQueue.main.async {
                completion?()
            }
        }.resume()
    }

    // MARK: - Outbound Call
    // ChatView calls makeCall(to:), so keep the same public API.
    // Internally:
    // 1) create sessionId
    // 2) connect app leg via Twilio Voice SDK with sessionId
    // 3) ask server to start PSTN leg into same conference
    func makeCall(to number: String) {
        guard let token = accessToken else {
            updateStatus("No token", color: .red)
            return
        }

        let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            updateStatus("No phone number", color: .red)
            return
        }

        let sessionId = UUID().uuidString
        currentSessionId = sessionId
        pendingPhoneNumber = trimmed
        reconnectAttempt = 0

        connectWebSocket(sessionId: sessionId)

        let connectOptions = ConnectOptions(accessToken: token) { builder in
            builder.params = [
                "sessionId": sessionId
            ]
        }

        updateStatus("Joining conference…", color: .orange)
        activeCall = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
    }

    // MARK: - Hang Up
    func hangUp() {
        activeCall?.disconnect()
        activeCall = nil
        isConnected = false
        isMuted = false
        disconnectWebSocket()
        updateStatus("Call ended", color: .gray)
    }

    // MARK: - Mute
    func toggleMute() {
        guard let call = activeCall else { return }
        isMuted.toggle()
        call.isMuted = isMuted
    }

    // MARK: - Speak text into the call
    // ChatView calls speak(text), so keep that API.
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let sessionId = currentSessionId else { return }
        guard let url = URL(string: speakEndpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "sessionId": sessionId,
            "text": trimmed,
            "target": "callee"
        ])

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error {
                print("Speak error: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - Start PSTN leg after app leg connects
    private func startPSTNLegIfNeeded() {
        guard let sessionId = currentSessionId,
              let phoneNumber = pendingPhoneNumber,
              let url = URL(string: startSessionEndpoint) else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "sessionId": sessionId,
            "to": phoneNumber
        ])

        URLSession.shared.dataTask(with: request) { [weak self] _, _, error in
            if let error {
                DispatchQueue.main.async {
                    self?.updateStatus("PSTN start failed: \(error.localizedDescription)", color: .red)
                }
                return
            }

            DispatchQueue.main.async {
                self?.updateStatus("Dialing remote party…", color: .orange)
            }
        }.resume()
    }

    // MARK: - WebSocket
    // Server contract is now /app?sessionId=...
    private func connectWebSocket(sessionId: String) {
        guard var components = URLComponents(string: serverBase) else { return }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/app"
        components.queryItems = [
            URLQueryItem(name: "sessionId", value: sessionId)
        ]

        guard let url = components.url else { return }

        manuallyClosedSocket = false
        urlSession = URLSession(configuration: .default)
        webSocket = urlSession?.webSocketTask(with: url)
        webSocket?.resume()
        startPingTimer()

        let registerMsg = try? JSONSerialization.data(withJSONObject: [
            "type": "register",
            "sessionId": sessionId
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
                guard !self.manuallyClosedSocket,
                      self.isConnected || self.currentSessionId != nil,
                      let sessionId = self.currentSessionId else { return }

                self.reconnectAttempt = min(self.reconnectAttempt + 1, 4)
                let delay = pow(2.0, Double(self.reconnectAttempt))

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self else { return }
                    guard !self.manuallyClosedSocket else { return }
                    self.connectWebSocket(sessionId: sessionId)
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

        if type == "transcription" {
            let transcript = json["transcript"] as? String ?? ""
            let isFinal = json["isFinal"] as? Bool ?? false

            DispatchQueue.main.async {
                self.onTranscriptionUpdate?(transcript, isFinal)
            }
        }

        if type == "speaking",
           let state = json["state"] as? String {
            let isSpeaking = (state == "start" || state == "queued")
            DispatchQueue.main.async {
                self.onSpeakingStateChange?(isSpeaking)
            }
        }

        if type == "call-status",
           let status = json["status"] as? String {
            DispatchQueue.main.async {
                switch status {
                case "ringing":
                    self.updateStatus("Remote party ringing…", color: .orange)
                case "answered":
                    self.updateStatus("Call connected", color: .green)
                case "completed":
                    self.updateStatus("Call ended", color: .gray)
                default:
                    break
                }
            }
        }

        if type == "conference",
           let event = json["event"] as? String {
            DispatchQueue.main.async {
                if event == "join" || event == "start" {
                    self.updateStatus("Conference active", color: .green)
                }
            }
        }

        if type == "server",
           let event = json["event"] as? String {
            DispatchQueue.main.async {
                if event == "registered" {
                    self.updateStatus("Session ready", color: .green)
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
                    self.disconnectWebSocket()
                    if let sessionId = self.currentSessionId, self.isConnected {
                        self.connectWebSocket(sessionId: sessionId)
                    }
                }
            }
        }
        if let pingTimer {
            RunLoop.main.add(pingTimer, forMode: .common)
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func disconnectWebSocket() {
        manuallyClosedSocket = true
        stopPingTimer()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        urlSession = nil
    }

    // MARK: - CallDelegate
    func callDidStartRinging(call: Call) {
        DispatchQueue.main.async {
            self.updateStatus("Connecting app audio…", color: .orange)
        }
    }

    func callDidConnect(call: Call) {
        print("APP CALL CONNECTED, sid:", call.sid)
        activeCall = call
        isConnected = true
        reconnectAttempt = 0
        updateStatus("App joined conference", color: .green)
        startPSTNLegIfNeeded()
    }

    func callDidDisconnect(call: Call, error: Error?) {
        print("APP CALL DISCONNECTED, sid:", call.sid, "error:", error?.localizedDescription ?? "none")
        isConnected = false
        isMuted = false
        activeCall = nil
        disconnectWebSocket()
        updateStatus(error != nil ? "Disconnected (error)" : "Call ended", color: .gray)
    }

    func callDidFailToConnect(call: Call, error: Error) {
        isConnected = false
        activeCall = nil
        disconnectWebSocket()
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
