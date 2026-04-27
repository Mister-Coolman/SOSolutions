import SwiftUI
import TwilioVoice
import PhotosUI
import RegexBuilder

struct Message: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var simpleText: String? = nil
    let isUser: Bool
    var showSimple: Bool = false
}

struct ChatViewTest: View {
    @Binding var inChat: Bool
    @Binding var callNumber: String

    @StateObject private var voiceManager = TwilioVoiceManager()

    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var composerHeight: CGFloat = 44
    @FocusState private var isComposerFocused: Bool

    // Camera / image analysis
    @State private var image: UIImage?
    @State private var descriptions: [String] = []
    @State private var currentIndex = 0
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showCamera = false
    @State private var cameraImage: UIImage?

    // Transcription accumulation
    @State private var currentTranscript: String = ""
    @State private var lastStableTranscript: String = ""
    @State private var silenceTimer: Timer?

    // Speaking state from VoIP manager
    @State private var isRemoteSpeaking = false
    @State private var isStartingCall = false
    @State private var hasStartedCall = false

    // Local simplifier
    @State private var llm = LLMEvaluator()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            if !descriptions.isEmpty {
                suggestionsView
                    .padding(.horizontal)
                    .padding(.top, 10)
            }
            composer
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !hasStartedCall else { return }
            hasStartedCall = true
            startCall()
        }
        .onDisappear {
            silenceTimer?.invalidate()
            silenceTimer = nil
        }
        .onChange(of: cameraImage) { _, newImage in
            guard let newImage else { return }
            image = newImage
            Task { await analyze(newImage) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $cameraImage)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut) {
                        inChat = false
                    }
                    voiceManager.hangUp()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.red)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(callNumber.isEmpty ? "Voice call" : callNumber)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(voiceManager.statusColor)
                            .frame(width: 8, height: 8)

                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .disabled(isLoading)
            }

            if isRemoteSpeaking || !currentTranscript.isEmpty || isLoading || errorMessage != nil {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: isRemoteSpeaking ? "waveform" : "captions.bubble")
                            .foregroundStyle(.secondary)
                    }

                    Text(bannerText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach($messages) { $message in
                        messageRow(message: $message)
                    }

                    if !currentTranscript.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Live transcript", systemImage: "waveform")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)

                                Text(currentTranscript)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Text("Listening…")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(Color.accentColor.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            Spacer(minLength: 40)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottomID")
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: currentTranscript) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: descriptions.count) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private func messageRow(message: Binding<Message>) -> some View {
        HStack {
            if message.wrappedValue.isUser {
                Spacer(minLength: 40)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(displayText(for: message.wrappedValue))
                    .foregroundStyle(message.wrappedValue.isUser ? .white : .primary)
                    .textSelection(.enabled)

                if !message.wrappedValue.isUser {
                    Text(message.wrappedValue.showSimple ? "Tap to show original" : "Tap to simplify")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(message.wrappedValue.isUser ? Color.accentColor : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !message.wrappedValue.isUser else { return }
                handleMessageTap(message)
            }

            if !message.wrappedValue.isUser {
                Spacer(minLength: 40)
            }
        }
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Suggestions", systemImage: "sparkles")
                    .font(.headline)

                Spacer()

                Button {
                    currentIndex = (currentIndex + 1) % descriptions.count
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)

                Button("Dismiss") {
                    descriptions.removeAll()
                }
                .font(.subheadline)
                .buttonStyle(.plain)
            }

            Button {
                inputText = descriptions[currentIndex]
                descriptions.removeAll()
                isComposerFocused = true
            } label: {
                Text(descriptions[currentIndex])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .background(Color.orange.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            GrowingTextView(text: $inputText, measuredHeight: $composerHeight)
                .focused($isComposerFocused)
                .frame(minHeight: 44, maxHeight: 120)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .disabled(!voiceManager.isConnected)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canSend ? Color.accentColor : Color.gray.opacity(0.35))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
        }
    }

    private var canSend: Bool {
        voiceManager.isConnected && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var statusText: String {
        if isStartingCall && !voiceManager.isConnected {
            return "Starting call…"
        }
        if isRemoteSpeaking {
            return "Speaking"
        }
        return voiceManager.callStatus
    }

    private var bannerText: String {
        if let errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        if isLoading {
            return "Analyzing photo…"
        }
        if isRemoteSpeaking {
            return "Audio is playing. You can keep typing without interrupting the call."
        }
        if !currentTranscript.isEmpty {
            return "Live transcript updating…"
        }
        return ""
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("bottomID", anchor: .bottom)
            }
        }
    }

    private func displayText(for message: Message) -> String {
        if message.showSimple, let simpleText = message.simpleText, !simpleText.isEmpty {
            return simpleText
        }
        return message.text
    }

    // MARK: - Start Call
    private func startCall() {
        isStartingCall = true

        voiceManager.onTranscriptionUpdate = { text, isFinal in
            DispatchQueue.main.async {
                let parsed = parseTranscript(text) ?? ""
                let cleaned = cleanedTranscriptPreview(parsed)

                guard !cleaned.isEmpty else { return }

                currentTranscript = cleaned
                silenceTimer?.invalidate()

                if isFinal {
                    commitTranscript(force: true)
                    return
                }

                guard shouldShowLiveTranscript(cleaned) else {
                    return
                }

                silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.75, repeats: false) { _ in
                    commitTranscript(force: false)
                }
                if let silenceTimer {
                    RunLoop.main.add(silenceTimer, forMode: .common)
                }
            }
        }

        voiceManager.onSpeakingStateChange = { isSpeaking in
            DispatchQueue.main.async {
                isRemoteSpeaking = isSpeaking
            }
        }

        voiceManager.fetchToken {
            isStartingCall = false
            voiceManager.makeCall(to: callNumber)
        }
    }

    // MARK: - Commit transcript as a new message bubble
    private func commitTranscript(force: Bool = false) {
        let cleaned = cleanedTranscriptPreview(currentTranscript)

        guard !cleaned.isEmpty else {
            currentTranscript = ""
            return
        }

        guard force || shouldCommitTranscript(cleaned) else {
            return
        }

        if lastStableTranscript == cleaned {
            currentTranscript = ""
            return
        }

        if messages.last?.isUser == false,
           messages.last?.text == cleaned {
            currentTranscript = ""
            lastStableTranscript = cleaned
            return
        }

        messages.append(Message(text: cleaned, isUser: false))
        lastStableTranscript = cleaned
        currentTranscript = ""
    }

    private func readTranscript(rawTranscript: String) -> String {
        parseTranscript(rawTranscript) ?? ""
    }

    private func parseTranscript(_ raw: String) -> String? {
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let transcript = json["transcript"] as? String {
            return transcript
        }
        return raw.isEmpty ? nil : raw
    }

    private func cleanedTranscriptPreview(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func shouldShowLiveTranscript(_ text: String) -> Bool {
        text.count >= 6
    }

    private func shouldCommitTranscript(_ text: String) -> Bool {
        text.count >= 12
    }

    // MARK: - Send Message
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        inputText = ""
        messages.append(Message(text: trimmed, isUser: true))
        voiceManager.speak(trimmed)
    }

    // MARK: - Image analysis
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
        if message.wrappedValue.showSimple {
            message.wrappedValue.showSimple = false
            return
        }

        if let simpleText = message.wrappedValue.simpleText, !simpleText.isEmpty {
            message.wrappedValue.showSimple = true
            return
        }

        let originalText = message.wrappedValue.text
        Task {
            await llm.generate(prompt: originalText, type: 0)
            let output = llm.output.trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                guard !output.isEmpty else { return }
                message.wrappedValue.simpleText = output
                message.wrappedValue.showSimple = true
            }
        }
    }

    private func isModelDownloading() -> Bool {
        llm.modelInfo.contains("Downloading")
    }

    private func isModelLoaded() -> Bool {
        llm.modelInfo.contains("Loaded")
    }

    private func getDownloadProgress() -> Double {
        let regex = Regex {
            "Downloading"
            ZeroOrMore(.any, .reluctant)
            ": "
            Capture {
                OneOrMore(.digit)
            }
            "%"
        }

        if let match = llm.modelInfo.firstMatch(of: regex),
           let percentage = Double(match.1) {
            return percentage
        }
        return 0
    }
}

private struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var measuredHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.returnKeyType = .default
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        DispatchQueue.main.async {
            let fittingSize = CGSize(width: uiView.bounds.width, height: .greatestFiniteMagnitude)
            let size = uiView.sizeThatFits(fittingSize)
            measuredHeight = min(max(size.height, 44), 120)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: GrowingTextView

        init(_ parent: GrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            let fittingSize = CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
            let size = textView.sizeThatFits(fittingSize)
            parent.measuredHeight = min(max(size.height, 44), 120)
        }
    }
}

