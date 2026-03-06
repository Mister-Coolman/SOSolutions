//
//  SpeechRecognizer.swift
//  SOSolutions
//
//  Created by Arjun Rangarajan on 2/13/26.
//

import SwiftUI
import Speech
import AVFoundation
import Combine

class SpeechRecognizer: NSObject, ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Request Permission
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Access granted to Speech Recognition")
                case .denied:
                    print("Access denied to Speech Recognition")
                case .restricted:
                    print("Access restricted to Speech Recognition")
                case .notDetermined:
                    print("Access not determined to Speech Recognition")
                @unknown default:
                    fatalError()
                }
            }
        }
    }
    
    func startRecording() {
        transcribedText = ""
        isRecording = true
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self.transcribedText = result.bestTranscription.formattedString
                    }
                }
                
                if error != nil {
                    self.stopRecording()
                }
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            
        } catch {
            print("Error starting recording \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        isRecording = false
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionTask = nil
        recognitionRequest = nil
    }
}
