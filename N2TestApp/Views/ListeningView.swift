import SwiftUI
import AVFoundation
import UIKit

struct ListeningView: View {
    @Binding var isTabBarHidden: Bool
    
    @State private var audioQuestions: [AudioQuestion] = []
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: String?
    @State private var showAnswer = false
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var score: Int = 0
    @State private var audioProgress: Float = 0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var updateTimer: Timer?
    @State private var endTimeTimer: Timer?
    @State private var showFullscreenImage = false
    @State private var showNextQuestion = false
    @State private var showMenu = false
    @State private var _delegate: AudioPlayerDelegate?
    @State private var fontScale: CGFloat = 1.2
    @State private var showResultSheet = false
    @State private var showScript = false
    @State private var hasScript: Bool = false
    @State private var currentScriptText: String = ""
    @State private var showPurchaseView: Bool = false
    @State private var selectedSet: Int? = nil
    @State private var isFromResult: Bool = false
    @State private var wrongAnswers: [Int] = []
    @State private var isRetryMode = false

    @State private var set1Progress: Double = 0
    @State private var set2Progress: Double = 0
    
    private var isScriptEntitled: Bool { storeManager.isSubscribed }
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var interstitialViewModel = InterstitialViewModel()
    @ObservedObject private var appAdManager = AppAdManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private let level: String = "TopikAudio"
    private var quizGroup: String { "Group3_set\(selectedSet ?? 0)" }
    
    private var bannerHeight: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .compact {
            return 90
        } else if horizontalSizeClass == .regular {
            return 100
        } else if horizontalSizeClass == .compact && verticalSizeClass == .compact {
            return 32
        } else {
            return 50
        }
    }
    
    private var currentQuestion: AudioQuestion? {
        guard !audioQuestions.isEmpty else { return nil }
        if isRetryMode && !wrongAnswers.isEmpty {
            let wrongIndex = wrongAnswers[currentQuestionIndex]
            return audioQuestions[wrongIndex]
        }
        return audioQuestions[currentQuestionIndex]
    }
    
    private var totalQuestionsCount: Int {
        isRetryMode ? wrongAnswers.count : audioQuestions.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    AdaptiveTopBannerView()

                    ZStack {
                        if selectedSet != nil {
                            (colorScheme == .dark ? Color.black : Color.white)
                                .ignoresSafeArea()
                            
                            GeometryReader { contentGeometry in
                                let availableHeight = contentGeometry.size.height
                                
                                ScrollView {
                                    VStack(spacing: 20) {
                                        // 메뉴
                                        HStack {
                                            Menu {
                                                Button(action: {
                                                    resetToFirstQuestion()
                                                }) {
                                                    Label("다시 시작", systemImage: "arrow.counterclockwise")
                                                }
                                                
                                                Button(action: {
                                                    stopAudio()
                                                    if let set = selectedSet, !isRetryMode {
                                                        DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: currentQuestionIndex)
                                                    }
                                                    selectedSet = nil
                                                    currentQuestionIndex = 0
                                                    selectedAnswer = nil
                                                    showAnswer = false
                                                    progress = 0
                                                    wrongAnswers = []
                                                    isRetryMode = false
                                                }) {
                                                    Label("세트 선택", systemImage: "list.number")
                                                }
                                                
                                                Button(action: {
                                                    dismiss()
                                                }) {
                                                    Label("메인으로 돌아가기", systemImage: "house.fill")
                                                }
                                                
                                                Menu("글자 크기") {
                                                    Button(action: { fontScale = 1.0 }) { Text("작게") }
                                                    Button(action: { fontScale = 1.2 }) { Text("보통") }
                                                    Button(action: { fontScale = 1.4 }) { Text("크게") }
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(colorScheme == .dark ? .orange : .blue)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                        
                                        Spacer()
                                        
                                        // 문제 표시 영역
                                        VStack(alignment: .center, spacing: 24) {
                                            if let questionText = currentQuestion?.question {
                                                Text(questionText)
                                                    .font(.custom("Hiragino Sans", size: 22 * fontScale, relativeTo: .body))
                                                    .multilineTextAlignment(.center)
                                                    .padding(.horizontal, 20)
                                                    .frame(maxWidth: .infinity)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            
                                            if let imageName = currentQuestion?.imageName,
                                               let image = UIImage(named: imageName) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(maxWidth: geometry.size.width * 0.8)
                                                    .onTapGesture {
                                                        showFullscreenImage = true
                                                    }
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                        )
                                        .padding(.horizontal, 20)
                                        
                                        // 재생/재시작 버튼
                                        HStack(spacing: 20) {
                                            Button(action: {
                                                togglePlayPause()
                                            }) {
                                                HStack {
                                                    Spacer()
                                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                                        .font(.system(size: 30))
                                                        .foregroundColor(.blue)
                                                    Spacer()
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.darkGray, lineWidth: 1)
                                                )
                                            }
                                            
                                            Button(action: {
                                                restartCurrentAudio()
                                            }) {
                                                HStack {
                                                    Spacer()
                                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                                        .font(.system(size: 30))
                                                        .foregroundColor(.blue)
                                                    Spacer()
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.darkGray, lineWidth: 1)
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        
                                        // 스크립트 버튼
                                        if showAnswer && hasScript {
                                            Button(action: {
                                                if isScriptEntitled {
                                                    showScript.toggle()
                                                } else {
                                                    isFromResult = false
                                                    showPurchaseView = true
                                                }
                                            }) {
                                                HStack {
                                                    Spacer()
                                                    HStack(spacing: 8) {
                                                        Text(showScript ? "스크립트 숨기기" : "스크립트")
                                                            .font(.system(size: 16))
                                                            .foregroundColor(.blue)
                                                        
                                                        if !isScriptEntitled {
                                                            Image(systemName: "lock.fill")
                                                                .font(.system(size: 14))
                                                                .foregroundColor(.blue)
                                                        }
                                                    }
                                                    Spacer()
                                                }
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.darkGray, lineWidth: 1)
                                                )
                                            }
                                            .padding(.horizontal, 20)
                                        }
                                        
                                        // 선택지 버튼
                                        VStack(spacing: 16) {
                                            ForEach(currentQuestion?.options ?? [], id: \.self) { option in
                                                Button(action: {
                                                    selectAnswer(option)
                                                }) {
                                                    HStack {
                                                        Spacer()
                                                        Text(option)
                                                            .font(.custom("Hiragino Sans", size: 18 * fontScale, relativeTo: .body))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                            .multilineTextAlignment(.center)
                                                            .padding(.vertical, 12)
                                                            .fixedSize(horizontal: false, vertical: true)
                                                        Spacer()
                                                        if showAnswer {
                                                            if option == currentQuestion?.answer {
                                                                Image(systemName: "checkmark.circle.fill")
                                                                    .foregroundColor(.green)
                                                                    .padding(.trailing, 8)
                                                            } else if option == selectedAnswer {
                                                                Image(systemName: "xmark.circle.fill")
                                                                    .foregroundColor(.red)
                                                                    .padding(.trailing, 8)
                                                            }
                                                        }
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.darkGray, lineWidth: 1)
                                                    )
                                                }
                                                .disabled(showAnswer)
                                            }
                                            
                                            if showAnswer {
                                                Button(action: { moveToNextQuestion() }) {
                                                    HStack {
                                                        Spacer()
                                                        Text(currentQuestionIndex < totalQuestionsCount - 1 ? "다음 문제" : "완료")
                                                            .font(.system(size: 18))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                            .multilineTextAlignment(.center)
                                                            .padding(.vertical, 12)
                                                        Spacer()
                                                    }
                                                    .frame(maxWidth: .infinity)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray)
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.darkGray, lineWidth: 1)
                                                    )
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        
                                        Spacer()
                                    }
                                    .frame(minHeight: availableHeight)
                                    .padding(.vertical)
                                }
                            }
                        } else {
                            // 세트 선택 화면
                            (colorScheme == .dark ? Color.black : Color.white).ignoresSafeArea()
                            GeometryReader { geo in
                                VStack(spacing: 0) {
                                    HStack {
                                        Button(action: { dismiss() }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                .padding()
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    
                                    ScrollView {
                                        VStack(spacing: 0) {
                                            // 1회 세트
                                            VStack(spacing: 0) {
                                                Spacer()
                                                Button(action: {
                                                    selectedSet = 1
                                                    loadQuestionsForSet(1)
                                                }) {
                                                    VStack(spacing: 16) {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill(Color.green.opacity(0.15))
                                                                .frame(width: min(geo.size.width * 0.35, 200), height: min(geo.size.width * 0.35, 200))
                                                            
                                                            Image(systemName: "headphones")
                                                                .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                .foregroundColor(.green)
                                                        }
                                                        
                                                        Text("1회")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        
                                                        VStack(spacing: 6) {
                                                            ProgressView(value: set1Progress)
                                                                .progressViewStyle(.linear)
                                                                .tint(.green)
                                                                .frame(width: min(geo.size.width * 0.5, 260))
                                                            Text(String(format: "%.0f%%", set1Progress * 100))
                                                                .font(.system(size: 14, weight: .semibold))
                                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        }
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .frame(height: max(geo.size.height * 0.45, 300))
                                            
                                            Divider()
                                                .background(colorScheme == .dark ? Color.gray : Color.gray.opacity(0.3))
                                            
                                            // 2회 세트
                                            VStack(spacing: 0) {
                                                Spacer()
                                                Button(action: {
                                                    if storeManager.isSubscribed {
                                                        selectedSet = 2
                                                        loadQuestionsForSet(2)
                                                    } else {
                                                        isFromResult = false
                                                        showPurchaseView = true
                                                    }
                                                }) {
                                                    VStack(spacing: 16) {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill((storeManager.isSubscribed ? Color.green : Color.orange).opacity(0.15))
                                                                .frame(width: min(geo.size.width * 0.35, 200), height: min(geo.size.width * 0.35, 200))
                                                            
                                                            if storeManager.isSubscribed {
                                                                Image(systemName: "headphones")
                                                                    .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                    .foregroundColor(.green)
                                                            } else {
                                                                ZStack {
                                                                    Image(systemName: "headphones")
                                                                        .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                        .foregroundColor(.orange.opacity(0.3))
                                                                    
                                                                    Image(systemName: "lock.fill")
                                                                        .font(.system(size: min(geo.size.width * 0.08, 40)))
                                                                        .foregroundColor(.orange)
                                                                }
                                                            }
                                                        }
                                                        
                                                        Text("2회")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        
                                                        VStack(spacing: 6) {
                                                            ProgressView(value: set2Progress)
                                                                .progressViewStyle(.linear)
                                                                .tint(storeManager.isSubscribed ? .green : .orange)
                                                                .frame(width: min(geo.size.width * 0.5, 260))
                                                            Text(String(format: "%.0f%%", set2Progress * 100))
                                                                .font(.system(size: 14, weight: .semibold))
                                                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        }
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .frame(height: max(geo.size.height * 0.45, 300))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    AdaptiveBottomBannerView()
                }
            }
        }
        .ignoresSafeArea(.container, edges: [.leading, .trailing])
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showFullscreenImage) {
            if let imageName = currentQuestion?.imageName,
               let image = UIImage(named: imageName) {
                FullscreenImageView(image: image) {
                    showFullscreenImage = false
                }
            }
        }
        .fullScreenCover(isPresented: $showScript) {
            if isScriptEntitled {
                FullscreenScriptView(
                    script: currentScriptText,
                    highlightedRange: NSRange(location: 0, length: 0),
                    dismissAction: { showScript = false },
                    fontScale: fontScale
                )
            } else {
                Color.clear.onAppear {
                    showScript = false
                    isFromResult = false
                    showPurchaseView = true
                }
            }
        }
        .sheet(isPresented: $showPurchaseView, onDismiss: {
            // 구독 완료 후 다시 체크
        }) {
            PurchaseView()
        }
        .sheet(isPresented: $showResultSheet) {
            let correctCount = score
            let wrongCount = totalQuestionsCount - score
            let accuracy = totalQuestionsCount > 0 ? Int(Double(score) / Double(totalQuestionsCount) * 100) : 0
            VStack(spacing: 24) {
                Text("퀴즈 결과")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("✔️ 정답수: \(correctCount)")
                    .font(.title2)
                    .foregroundColor(.green)
                Text("❌ 오답수: \(wrongCount)")
                    .font(.title2)
                    .foregroundColor(.red)
                Text("📊 정답률: \(accuracy)%")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Button(action: {
                    handleResultConfirm()
                }) {
                    Text("확인")
                        .font(.title3)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // 오답 재도전 버튼
                if !isRetryMode && !wrongAnswers.isEmpty {
                    Button(action: {
                        stopAudio()
                        audioPlayer = nil
                        
                        currentQuestionIndex = 0
                        selectedAnswer = nil
                        showAnswer = false
                        score = 0
                        audioProgress = 0
                        isPlaying = false
                        showScript = false
                        isRetryMode = true
                        progress = 0
                        
                        showResultSheet = false
                        setupAudio()
                    }) {
                        Text("틀린 문제만 다시 풀기")
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 400)
        }
        .onAppear {
            isTabBarHidden = true
            configureAudioSession()
            if let set = selectedSet, !isRetryMode {
                let saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group3_set\(set)")
                currentQuestionIndex = (saved < audioQuestions.count) ? saved : 0
                progress = Double(currentQuestionIndex) / Double(max(audioQuestions.count, 1))
            } else {
                currentQuestionIndex = 0
                progress = 0
            }
            Task { await interstitialViewModel.loadAd() }
            refreshSetProgress()
        }
        .onDisappear {
            isTabBarHidden = false
            if let set = selectedSet, !isRetryMode {
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: currentQuestionIndex)
            }
            stopAudio()
            refreshSetProgress()
        }
        .onChange(of: currentQuestionIndex) { _, newValue in
            if let set = selectedSet, !isRetryMode {
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: newValue)
            }
            progress = Double(newValue) / Double(totalQuestionsCount)
            refreshSetProgress()
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("오디오 세션 설정 완료")
        } catch {
            print("오디오 세션 설정 실패: \(error.localizedDescription)")
        }
    }
    
    private func restartCurrentAudio() {
        guard let player = audioPlayer, let question = currentQuestion else { return }

        if let start = question.startTime,
           let end = question.endTime,
           end > start {
            // 🔹 분할 오디오
            player.currentTime = start
            setupEndTimeTimer()
        } else {
            // 🔹 개별 m4a → 전체 재생
            player.currentTime = 0
            endTimeTimer?.invalidate()
        }

        player.play()
        isPlaying = true
    }
    
    private func loadQuestionsForSet(_ set: Int) {
        audioQuestions = AudioDataLoader.load(set: set)

        let savedIndex = DatabaseManager.shared.loadProgress(
            level: level,
            quizGroup: "Group3_set\(set)"
        )

        currentQuestionIndex =
            (savedIndex < audioQuestions.count) ? savedIndex : 0

        progress = audioQuestions.isEmpty
            ? 0
            : Double(currentQuestionIndex) / Double(audioQuestions.count)

        selectedAnswer = nil
        showAnswer = false
        audioProgress = 0
        isPlaying = false
        wrongAnswers = []
        isRetryMode = false

        stopAudio()
        setupAudio()
    }
    
    private func refreshSetProgress() {
        let set1Questions = AudioDataLoader.load(set: 1)
        let set1Saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group3_set1")
        set1Progress = set1Questions.isEmpty
            ? 0
            : Double(min(set1Saved, max(set1Questions.count - 1, 0)))
              / Double(max(set1Questions.count, 1))

        let set2Questions = AudioDataLoader.load(set: 2)
        let set2Saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group3_set2")
        set2Progress = set2Questions.isEmpty
            ? 0
            : Double(min(set2Saved, max(set2Questions.count - 1, 0)))
              / Double(max(set2Questions.count, 1))
    }
    
    private func setupAudio() {
        guard let question = currentQuestion else { return }
        
        let script = ScriptData.getScript(for: question.audioFileName)
        self.currentScriptText = script ?? ""
        self.hasScript = (script != nil)
        
        guard let url = Bundle.main.url(forResource: question.audioFileName, withExtension: nil) else {
            print("오디오 파일을 찾을 수 없습니다: \(question.audioFileName)")
            return
        }
        
        do {
            configureAudioSession()
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            
            if let start = question.startTime,
               let end = question.endTime,
               end > start {
                // 🔹 분할 오디오
                audioPlayer?.currentTime = start
                setupEndTimeTimer()
            } else {
                // 🔹 개별 m4a
                audioPlayer?.currentTime = 0
                endTimeTimer?.invalidate()
            }
            
            let delegate = AudioPlayerDelegate(isPlaying: $isPlaying)
            _delegate = delegate
            audioPlayer?.delegate = delegate
            
            startProgressUpdateTimer()
            setupEndTimeTimer()
            
            print("오디오 파일 로드 성공: \(question.audioFileName)")
        } catch {
            print("오디오 플레이어 초기화 실패: \(error.localizedDescription)")
        }
    }
    
    private func setupEndTimeTimer() {
        endTimeTimer?.invalidate()
        endTimeTimer = nil
        
        guard let question = currentQuestion,
              let player = audioPlayer,
              let startTime = question.startTime,
              let endTime = question.endTime,
              endTime > startTime else {
            // 🔹 개별 m4a → 타이머 필요 없음
            return
        }
        
        if player.currentTime < startTime {
            player.currentTime = startTime
        }
        
        let remainingTime = endTime - player.currentTime
        
        if remainingTime > 0 {
            endTimeTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { _ in
                self.stopAudioAtEndTime()
            }
        }
    }
    
    private func stopAudioAtEndTime() {
        audioPlayer?.pause()
        isPlaying = false
        
        if let startTime = currentQuestion?.startTime {
            audioPlayer?.currentTime = startTime
        }
    }
    
    private func startProgressUpdateTimer() {
        updateTimer?.invalidate()

        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.audioPlayer,
                  let question = self.currentQuestion else { return }

            // 🔹 분할 오디오인지 판별
            if let startTime = question.startTime,
               let endTime = question.endTime,
               endTime > startTime {

                let duration = endTime - startTime
                let currentOffset = player.currentTime - startTime

                if duration > 0 {
                    self.audioProgress = Float(
                        max(0, min(currentOffset / duration, 1.0))
                    )
                } else {
                    self.audioProgress = 0
                }

                if player.currentTime >= endTime {
                    self.stopAudioAtEndTime()
                }

            } else {
                // 🔹 개별 m4a 전체 재생
                if player.duration > 0 {
                    self.audioProgress = Float(player.currentTime / player.duration)
                } else {
                    self.audioProgress = 0
                }

                if !player.isPlaying && player.currentTime >= player.duration {
                    self.isPlaying = false
                    self.updateTimer?.invalidate()
                }
            }

            // 🔹 재생 상태 동기화
            if player.isPlaying {
                self.isPlaying = true
            } else {
                self.isPlaying = false
            }
        }
    }

    private func togglePlayPause() {
        guard let player = audioPlayer, let question = currentQuestion else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
            endTimeTimer?.invalidate()
        } else {
            if let startTime = question.startTime, let endTime = question.endTime {
                if player.currentTime < startTime || player.currentTime >= endTime {
                    player.currentTime = startTime
                }
            } else {
                if player.currentTime >= player.duration {
                    player.currentTime = 0
                }
            }
            
            player.play()
            isPlaying = true
            startProgressUpdateTimer()
            setupEndTimeTimer()
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        
        if let startTime = currentQuestion?.startTime {
            audioPlayer?.currentTime = startTime
        } else {
            audioPlayer?.currentTime = 0
        }
        
        updateTimer?.invalidate()
        updateTimer = nil
        endTimeTimer?.invalidate()
        endTimeTimer = nil
        isPlaying = false
    }
    
    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        showAnswer = true
        
        if answer == currentQuestion?.answer {
            score += 1
        } else {
            // 틀린 문제 인덱스 저장
            if !isRetryMode {
                let actualIndex = currentQuestionIndex
                if !wrongAnswers.contains(actualIndex) {
                    wrongAnswers.append(actualIndex)
                }
            }
        }
        
        if !isScriptEntitled {
            showScript = false
        }
    }
    
    private func moveToNextQuestion() {
        if currentQuestionIndex < totalQuestionsCount - 1 {
            stopAudio()
            audioPlayer = nil
            
            currentQuestionIndex += 1
            selectedAnswer = nil
            showAnswer = false
            audioProgress = 0
            isPlaying = false
            
            setupAudio()
            refreshSetProgress()
        } else {
            // 마지막 문제 도달 시
            // 1회이고 구독 안 되어 있으면 구독 화면 표시
            if selectedSet == 1 && !storeManager.isSubscribed && !isRetryMode {
                isFromResult = true
                showPurchaseView = true
            } else {
                // 그 외의 경우 결과창 표시
                showResultSheet = true
            }
        }
    }
    
    private func handleResultConfirm() {
        if let set = selectedSet {
            DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group3_set\(set)")
            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: 0)
            
            currentQuestionIndex = 0
            selectedAnswer = nil
            showAnswer = false
            progress = 0
            score = 0
            audioProgress = 0
            isPlaying = false
            showScript = false
            wrongAnswers = []
            isRetryMode = false
            
            selectedSet = nil
            audioQuestions = []
        }
        stopAudio()
        showResultSheet = false
        dismiss()
    }
    
    private func resetToFirstQuestion() {
        stopAudio()
        audioPlayer = nil
        
        currentQuestionIndex = 0
        progress = 0
        score = 0
        selectedAnswer = nil
        showAnswer = false
        audioProgress = 0
        isPlaying = false
        showScript = false
        wrongAnswers = []
        isRetryMode = false
        
        setupAudio()
        DatabaseManager.shared.resetProgress(level: level, quizGroup: quizGroup)
        if let set = selectedSet {
            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: 0)
        }
    }
    
    private func resetAndDismiss() {
        if let set = selectedSet {
            DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group3_set\(set)")
        }
        
        currentQuestionIndex = 0
        selectedAnswer = nil
        showAnswer = false
        progress = 0
        score = 0
        audioProgress = 0
        isPlaying = false
        showScript = false
        selectedSet = nil
        audioQuestions = []
        wrongAnswers = []
        isRetryMode = false
        isTabBarHidden = false
        stopAudio()
        dismiss()
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    @Binding var isPlaying: Bool

    init(isPlaying: Binding<Bool>) {
        self._isPlaying = isPlaying
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
        print("오디오 디코딩 에러: \(error?.localizedDescription ?? "알 수 없음")")
    }
}
