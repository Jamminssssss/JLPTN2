import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    
    private var synthesizer = AVSpeechSynthesizer()
    private var lastSpeechTime: Date?
    private let speechCooldown: TimeInterval = 1.0 // 1초 쿨다운
    
    private init() {}
    
    func speakJapanese(text: String) {
        // 쿨다운 체크
        if let lastTime = lastSpeechTime {
            let timeSinceLastSpeech = Date().timeIntervalSince(lastTime)
            if timeSinceLastSpeech < speechCooldown {
                return
            }
        }
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        if let voice = AVSpeechSynthesisVoice(language: "ja-JP") {
            utterance.voice = voice
        }
        
        utterance.rate = 0.4
        utterance.pitchMultiplier = 1.2
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        synthesizer.speak(utterance)
        lastSpeechTime = Date()
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
