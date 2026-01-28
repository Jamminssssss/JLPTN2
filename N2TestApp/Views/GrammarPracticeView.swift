import SwiftUI
import AVFoundation
import Speech

struct GrammarPracticeView: View {
    @StateObject private var grammarController = GrammarController()
    @State private var isHighlighted = false
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    
    // TTS 관련 상태 변수
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var isSpeaking = false
    
    // 녹음 관련 상태 변수들
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isRecording = false
    @State private var isPlaying = false
    @State private var accuracy: Double?
    @State private var showAccuracy = false
    @State private var showPurchaseView = false
    @StateObject private var storeManager = StoreKitManager.shared
    
    // 구독 여부에 따른 녹음 권한
    private var isRecordingEntitled: Bool { storeManager.isSubscribed }
    
    // 폰트 크기 조절을 위한 상태 변수
    @State private var fontScale = 1.0
    
    // 광고 관련 상태 - 앱 레벨에서 전역 관리
    @StateObject private var interstitialViewModel = InterstitialViewModel()
    @ObservedObject private var appAdManager = AppAdManager.shared
    
    // 현재 언어 코드 가져오기
    private var currentLanguageCode: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    // 로컬라이징된 뜻 가져오기 (일본어는 뜻을 표시하지 않음)
    private func getLocalizedMeaning() -> String? {
        // 일본어 사용자는 뜻을 표시하지 않음
        if currentLanguageCode == "ja" {
            return nil
        }
        
        // 각 언어별로 뜻 반환
        switch currentLanguageCode {
        case "ko":
            return currentExample.meanings["ko"]
        case "zh", "zh-Hans", "zh-Hant":
            return currentExample.meanings["zh-Hans"]
        default:
            // 그 외 언어는 영어로 기본 표시
            return currentExample.meanings["en"]
        }
    }
    
    // 로컬라이징된 번역 가져오기 (일본어는 번역을 표시하지 않음)
    private func getLocalizedTranslation() -> String? {
        // 일본어 사용자는 번역을 표시하지 않음
        if currentLanguageCode == "ja" {
            return nil
        }
        
        switch currentLanguageCode {
        case "ko":
            return currentExample.translations["ko"] ?? currentExample.translations["en"] ?? ""
        case "zh", "zh-Hans", "zh-Hant":
            return currentExample.translations["zh-Hans"] ?? currentExample.translations["en"] ?? ""
        default:
            return currentExample.translations["en"] ?? ""
        }
    }
    
    // 화면 방향과 기기에 따른 배너 높이 계산 - 풀 배너 대응
    private var bannerHeight: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .compact {
            // iPad 가로 모드: 리더보드 배너 (728x90)
            return 90
        } else if horizontalSizeClass == .regular {
            // iPad 세로 모드: 대형 배너
            return 100
        } else if horizontalSizeClass == .compact && verticalSizeClass == .compact {
            // iPhone 가로 모드: 스마트 배너
            return 32
        } else {
            // iPhone 세로 모드: 표준 배너
            return 50
        }
    }
    
    var currentExample: GrammarExample {
        GrammarExample.examples[grammarController.currentExampleIndex]
    }
    
    private func highlightGrammarInExample() -> Text {
        let example = currentExample.example
        let grammar = currentExample.grammar
        
        if let range = example.range(of: grammar, options: .literal) {
            let before = String(example[..<range.lowerBound])
            let highlighted = String(example[range])
            let after = String(example[range.upperBound...])
            
            return Text(before) + Text(highlighted).foregroundColor(.red) + Text(after)
        }
        
        return Text(example)
    }
    
    // 오디오 세션 설정
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            
            // 마이크 이득 설정
            try session.setInputGain(1.0)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    // 녹음 상태 초기화
    private func resetRecordingState() {
        // 녹음 상태 초기화
        isRecording = false
        isPlaying = false
        showAccuracy = false
        accuracy = nil
        
        // 오디오 플레이어 중지 및 해제
        audioPlayer?.stop()
        audioPlayer = nil
        
        // 녹음 파일 삭제
        let fileManager = FileManager.default
        let audioURL = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        if fileManager.fileExists(atPath: audioURL.path) {
            try? fileManager.removeItem(at: audioURL)
        }
    }
    
    // 녹음 시작
    private func startRecording() {
        if !isRecordingEntitled {
            showPurchaseView = true
            return
        }
        // 이전 녹음 상태 초기화
        resetRecordingState()
        
        setupAudioSession()
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Recording failed: \(error)")
        }
    }
    
    // 녹음 중지
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        // 음성 인식을 통한 정확도 측정
        measureAccuracy()
    }
    
    // 정확도 측정
    private func measureAccuracy() {
        if !isRecordingEntitled {
            showPurchaseView = true
            return
        }
        guard let audioURL = getDocumentsDirectory().appendingPathComponent("recording.m4a") as URL? else { return }
        
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja"))
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        
        recognizer?.recognitionTask(with: request) { (result, error) in
            guard let result = result else { return }
            
            let userText = result.bestTranscription.formattedString
            let correctText = currentExample.example
            
            // Levenshtein 거리를 사용한 정확도 계산
            let accuracy = calculateAccuracy(userText: userText, correctText: correctText)
            DispatchQueue.main.async {
                self.accuracy = accuracy
                self.showAccuracy = true
            }
        }
    }
    
    // 정확도 계산 함수
    private func calculateAccuracy(userText: String, correctText: String) -> Double {
        let userChars = Array(userText)
        let correctChars = Array(correctText)
        
        let maxLength = max(userChars.count, correctChars.count)
        if maxLength == 0 { return 0 }
        
        var matches = 0
        for i in 0..<min(userChars.count, correctChars.count) {
            if userChars[i] == correctChars[i] {
                matches += 1
            }
        }
        
        return Double(matches) / Double(maxLength) * 100
    }
    
    // 녹음 재생
    private func playRecording() {
        if !isRecordingEntitled {
            showPurchaseView = true
            return
        }
        guard let audioURL = getDocumentsDirectory().appendingPathComponent("recording.m4a") as URL? else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            
            // 재생이 끝나면 상태 업데이트
            DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                isPlaying = false
            }
        } catch {
            print("Playback failed: \(error)")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // TTS 음성 재생 함수
    private func speakText(_ text: String) {
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // 오디오 세션을 활성화하여 TTS가 정상적으로 작동하도록 보장합니다.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session for speech: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isSpeaking = true
        speechSynthesizer.speak(utterance)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSpeaking = false
        }
    }
    
    // 다음 예문으로 이동 (3번째 예문에서 광고 표시)
    private func moveToNextExample() {
        // 3번째 예문(인덱스 2)로 이동할 때 광고 표시 (앱이 실행되는 동안 1번만)
        if grammarController.currentExampleIndex == 2 && !appAdManager.hasShownGrammarAd {
            Task {
                await interstitialViewModel.loadAd()
                if interstitialViewModel.isAdReady {
                    interstitialViewModel.showAd()
                    appAdManager.hasShownGrammarAd = true
                }
            }
        }
        
        grammarController.nextExample(totalExamples: GrammarExample.examples.count)
        resetRecordingState()
    }
    
    // 녹음/재생 버튼 생성 함수 (자물쇠 아이콘 포함)
    @ViewBuilder
    private func recordingButtons() -> some View {
        Group {
            // 녹음 버튼
            Button(action: {
                if !isRecordingEntitled {
                    showPurchaseView = true
                } else {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 44, height: 44)
                    
                    if isRecordingEntitled {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.white)
                    } else {
                        // 구독하지 않았으면 자물쇠만 표시
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            
            // 재생 버튼
            Button(action: {
                if !isRecordingEntitled {
                    showPurchaseView = true
                } else {
                    playRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 44, height: 44)
                    
                    if isRecordingEntitled {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.white)
                    } else {
                        // 구독하지 않았으면 자물쇠만 표시
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // 일본어 문장과 로컬라이징된 번역을 함께 표시하는 뷰
    @ViewBuilder
    private func exampleTextWithTranslation() -> some View {
        VStack(spacing: 15) {
            highlightGrammarInExample()
                .font(.system(size: (horizontalSizeClass == .regular ? 50 : 40) * fontScale))
                .fontWeight(.bold)
                .padding()
                .background(isHighlighted ? Color.yellow.opacity(0.3) : Color.clear)
                .cornerRadius(10)
                .onTapGesture {
                    isHighlighted = true
                    DispatchQueue.main.async {
                        speakText(currentExample.example)
                    }
                    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isHighlighted = false
                        }
                    }
                }
            
            // 로컬라이징된 번역 표시 (일본어는 nil이므로 표시 안됨)
            if let translation = getLocalizedTranslation() {
                Text(translation)
                    .font(.system(size: (horizontalSizeClass == .regular ? 28 : 22) * fontScale))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // 상단 풀 배너
                    AdaptiveTopBannerView()
                    
                    // 메인 컨텐츠
                    ZStack {
                        if grammarController.showCompletionScreen {
                            // 모든 예문 학습 완료 시 화면 (기능은 예문 화면과 동일)
                            VStack(spacing: 0) {
                                Spacer()
                                VStack(spacing: 30) {
                                    exampleTextWithTranslation()
                                    
                                    // 구독한 경우에만 정확도 표시
                                    if showAccuracy && isRecordingEntitled {
                                        Text("정확도: \(String(format: "%.1f", accuracy ?? 0))%")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                            .padding()
                                    }
                                }
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity)
                                Spacer()
                                HStack(spacing: 16) {
                                    Button(action: {
                                        grammarController.previousExample()
                                        resetRecordingState()
                                    }) {
                                        Image(systemName: "arrow.left")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            grammarController.showExample = false
                                        }
                                        DispatchQueue.main.async {
                                            speakText(currentExample.grammar)
                                        }
                                        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                grammarController.showExample = true
                                            }
                                        }
                                    }) {
                                        Image(systemName: "eye")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    
                                    // 녹음/재생 버튼 (항상 표시, 자물쇠로 잠김)
                                    recordingButtons()
                                }
                                .padding(.vertical, 16)
                                .padding(.bottom, 20)
                            }
                        } else if !grammarController.showExample {
                            // 문법 표시 화면 (눈알 아이콘 클릭 시)
                            Color.black
                                .ignoresSafeArea()
                                .overlay(
                                    VStack(spacing: 30) {
                                        // 문법 표시
                                        Text(currentExample.grammar)
                                            .font(.system(size: (horizontalSizeClass == .regular ? 160 : 120) * fontScale))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding()
                                        
                                        // 로컬라이징된 뜻 표시 (일본어는 nil이므로 표시 안됨)
                                        if let meaning = getLocalizedMeaning() {
                                            Text(meaning)
                                                .font(.system(size: (horizontalSizeClass == .regular ? 28 : 22) * fontScale))
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal)
                                        }
                                    }
                                )
                                .transition(.opacity)
                                .onAppear {
                                    // 3초 후 예문 화면으로 자동 전환
                                    Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            grammarController.showExample = true
                                        }
                                    }
                                }
                        } else {
                            // 예문 화면
                            VStack(spacing: 0) {
                                Spacer()
                                
                                VStack(spacing: 30) {
                                    exampleTextWithTranslation()
                                    
                                    // 구독한 경우에만 정확도 표시
                                    if showAccuracy && isRecordingEntitled {
                                        Text("정확도: \(String(format: "%.1f", accuracy ?? 0))%")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                            .padding()
                                    }
                                }
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity)
                                
                                Spacer()
                                
                                HStack(spacing: 16) {
                                    Button(action: {
                                        grammarController.previousExample()
                                        resetRecordingState()
                                    }) {
                                        Image(systemName: "arrow.left")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            grammarController.showExample = false
                                        }
                                        // 음성 재생을 메인 스레드에서 실행
                                        DispatchQueue.main.async {
                                            speakText(currentExample.grammar)
                                        }
                                        // 3초 후에 화면 전환
                                        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                grammarController.showExample = true
                                            }
                                        }
                                    }) {
                                        Image(systemName: "eye")
                                            .font(.system(size: 20, weight: .regular))
                                            .foregroundColor(.white)
                                            .frame(width: 44, height: 44)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    
                                    // 녹음/재생 버튼 (항상 표시, 자물쇠로 잠김)
                                    recordingButtons()
                                    
                                    if grammarController.currentExampleIndex < GrammarExample.examples.count - 1 {
                                        Button(action: {
                                            moveToNextExample()
                                        }) {
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: 20, weight: .regular))
                                                .foregroundColor(.white)
                                                .frame(width: 44, height: 44)
                                                .background(Color.blue)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                                .padding(.vertical, 16)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 하단 풀 배너
                    AdaptiveBottomBannerView()

                }
            }
        }
        .ignoresSafeArea(.container, edges: [.leading, .trailing]) // 좌우 여백 제거
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar) // 탭바 숨기기
        .sheet(isPresented: $showPurchaseView) {
            PurchaseView()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button(action: {
                        grammarController.resetProgress()
                        ProgressManager.shared.clearGrammarProgress()
                        grammarController.currentExampleIndex = 0
                        grammarController.showCompletionScreen = false
                        grammarController.showExample = false
                        resetRecordingState()
                    }) {
                        Label("Restart", systemImage: "arrow.counterclockwise")
                    }
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Label("Return to Main Screen", systemImage: "house.fill")
                    }
                    Menu("Font Size") {
                        Button(action: {
                            fontScale = 0.8
                        }) {
                            Text("Small")
                        }
                        Button(action: {
                            fontScale = 1.0
                        }) {
                            Text("Medium")
                        }
                        Button(action: {
                            fontScale = 1.2
                        }) {
                            Text("Large")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            grammarController.loadProgress()
            // 광고 미리 로드
            Task {
                await interstitialViewModel.loadAd()
            }
            // 음성 인식 권한 요청
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    print("Speech recognition denied")
                case .restricted:
                    print("Speech recognition restricted")
                case .notDetermined:
                    print("Speech recognition not determined")
                @unknown default:
                    print("Speech recognition unknown status")
                }
            }
        }
        .onDisappear {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            resetRecordingState()
        }
    }
}
