// ListeningView.swift — EXAM PAPER REDESIGN (Yellow/Gold Theme)
// Preserves 100% of JLPT logic, audio playback, and state management
// UI structurally matches Exam style, Yellow/Gold tokens

import SwiftUI
import AVFoundation
import UIKit

// MARK: - Exam Colour Tokens (노란색/골드 계열 테마 적용)

private extension Color {
    static func examPaper(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.10, green: 0.09, blue: 0.08)
                   : Color(red: 1.00, green: 0.99, blue: 0.97) // 따뜻한 미색 배경
    }
    static func examCard(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.16, green: 0.14, blue: 0.12)
                   : Color(red: 1.00, green: 0.995, blue: 0.98)
    }
    static func examBorder(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.38, green: 0.35, blue: 0.28)
                   : Color(red: 0.85, green: 0.75, blue: 0.50)
    }
    /// 시험용 메인 노란색 (기존 examBlue 대체)
    static var examYellow: Color { Color(red: 0.85, green: 0.65, blue: 0.15) }
    /// 해설 골드 (기존 유지)
    static var examGold: Color { Color(red: 0.70, green: 0.48, blue: 0.08) }
}

struct ListeningView: View {
    @Binding var isTabBarHidden: Bool
    
    // MARK: - 기존 상태 (로직 100% 유지)
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
    @State private var wrongAnswers: [Int] = []
    @State private var isRetryMode = false

    // MARK: - 스크러빙 상태 (UI/UX 개선용)
    @State private var isScrubbing: Bool = false
    @State private var wasPlayingBeforeScrub: Bool = false

    // 세트 진행도 (1, 2, 3회차)
    @State private var set1Progress: Double = 0
    @State private var set2Progress: Double = 0
    @State private var set3Progress: Double = 0

    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var interstitialViewModel = InterstitialViewModel()
    @ObservedObject private var appAdManager = AppAdManager.shared
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private let level: String = "TopikAudio"
    private var quizGroup: String { "Group3_set\(selectedSet ?? 0)" }
    private var cs: ColorScheme { colorScheme }
    
    // MARK: - Computed Properties (기존 로직 유지)
    private var currentQuestion: AudioQuestion? {
        guard !audioQuestions.isEmpty else { return nil }
        if isRetryMode && !wrongAnswers.isEmpty {
            return audioQuestions[wrongAnswers[currentQuestionIndex]]
        }
        return audioQuestions[currentQuestionIndex]
    }
    
    private var totalQuestionsCount: Int {
        isRetryMode ? wrongAnswers.count : audioQuestions.count
    }

    private var isCurrentQuestionLocked: Bool {
        guard let set = selectedSet else { return false }
        if storeManager.isPremium { return false }
        return set != 1
    }

    private var isScriptEntitled: Bool {
        if storeManager.isPremium { return true }
        if let set = selectedSet, set == 1, currentQuestionIndex <= 2 {
            return true
        }
        return false
    }

    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    AdaptiveTopBannerView()

                    ZStack {
                        if selectedSet != nil {
                            Color.examPaper(cs).ignoresSafeArea()
                            
                            GeometryReader { inner in
                                ScrollView {
                                    VStack(spacing: 0) {
                                        examHeader
                                        examProgressBar
                                        
                                        VStack(spacing: 16) {
                                            if let q = currentQuestion {
                                                singleQuestionView(q: q, geometry: geometry)
                                            }
                                            
                                            if showAnswer {
                                                nextButton.padding(.top, 4)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .frame(minHeight: inner.size.height - 64)
                                    }
                                }
                            }
                        } else {
                            // 세트 선택 화면 (노란색 테마 적용)
                            Color.examPaper(cs).ignoresSafeArea()
                            GeometryReader { geo in
                                VStack(spacing: 0) {
                                    HStack {
                                        Button(action: { dismiss() }) {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(cs == .dark ? .white : .black)
                                                .padding()
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    
                                    ScrollView {
                                        setSelectionGrid(geo: geo)
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
                FullscreenImageView(image: image) { showFullscreenImage = false }
            }
        }
        .fullScreenCover(isPresented: $showPurchaseView){
            PurchaseView()
        }
        .fullScreenCover(isPresented: $showResultSheet) {
            resultSheet
        }
        .onAppear {
            isTabBarHidden = true
            configureAudioSession()
            if let set = selectedSet, !isRetryMode {
                let saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group3_set\(set)")
                currentQuestionIndex = (saved < audioQuestions.count) ? saved : 0
                progress = Double(currentQuestionIndex) / Double(max(audioQuestions.count, 1))
            } else {
                currentQuestionIndex = 0; progress = 0
            }
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
            progress = Double(newValue) / Double(max(totalQuestionsCount, 1))
            refreshSetProgress()
        }
    }

    // MARK: - Exam Header

    private var examHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Menu {
                    Button { resetToFirstQuestion() } label: {
                        Label("다시 시작", systemImage: "arrow.counterclockwise")
                    }
                    Button {
                        stopAudio()
                        if let set = selectedSet, !isRetryMode {
                            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: currentQuestionIndex)
                        }
                        selectedSet = nil; currentQuestionIndex = 0
                        selectedAnswer = nil; showAnswer = false
                        progress = 0; wrongAnswers = []; isRetryMode = false
                    } label: { Label("세트 선택", systemImage: "list.number") }
                    Button { dismiss() } label: {
                        Label("메인으로 돌아가기", systemImage: "house.fill")
                    }
                    Menu("글자 크기") {
                        Button("작게")  { fontScale = 1.0 }
                        Button("보통")  { fontScale = 1.2 }
                        Button("크게")  { fontScale = 1.4 }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(cs == .dark ? .white.opacity(0.6) : .black.opacity(0.45))
                        .frame(width: 44, height: 44)
                }

                Spacer()

                VStack(spacing: 3) {
                    Text("JLPT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.examYellow).kerning(1.5)
                    Text("聴  解")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(cs == .dark ? .white.opacity(0.45) : .black.opacity(0.40))
                        .kerning(4)
                }

                Spacer()

                Text("\(currentQuestionIndex + 1)／\(max(totalQuestionsCount, 1))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(cs == .dark ? .white.opacity(0.5) : .black.opacity(0.45))
                    .frame(width: 60, alignment: .trailing)
                    .padding(.trailing, 16)
            }
            .frame(height: 50)

            VStack(spacing: 3) {
                Rectangle().fill(Color.examYellow).frame(height: 2)
                Rectangle().fill(Color.examYellow.opacity(0.25)).frame(height: 1)
            }
        }
        .background(Color.examCard(cs))
    }

    // MARK: - Progress Bar

    private var examProgressBar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Color.examBorder(cs).opacity(0.18)
                Color.examYellow.opacity(0.65)
                    .frame(width: g.size.width * CGFloat(currentQuestionIndex + 1) /
                           CGFloat(max(totalQuestionsCount, 1)))
                    .animation(.easeInOut(duration: 0.3), value: currentQuestionIndex)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Set Selection Grid

    @ViewBuilder
    private func setSelectionGrid(geo: GeometryProxy) -> some View {
        let iconSize: CGFloat = min(geo.size.width * 0.22, 100)
        let lockSize: CGFloat = iconSize * 0.45
        // 1~3회 진행도
        let progresses = [set1Progress, set2Progress, set3Progress]
        
        VStack(spacing: 0) {
            ForEach(1...3, id: \.self) { setNum in
                let unlocked = storeManager.isPremium || setNum == 1
                let prog = setNum <= progresses.count ? progresses[setNum - 1] : 0.0
                
                Button {
                    if unlocked {
                        selectedSet = setNum
                        loadQuestionsForSet(setNum)
                    } else {
                        showPurchaseView = true
                    }
                } label: {
                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill((unlocked ? Color.examYellow : Color.orange).opacity(0.13))
                                .frame(width: iconSize * 1.6, height: iconSize * 1.6)
                            if unlocked {
                                Image(systemName: "headphones")
                                    .font(.system(size: iconSize))
                                    .foregroundColor(Color.examYellow)
                            } else {
                                ZStack {
                                    Image(systemName: "headphones")
                                        .font(.system(size: iconSize))
                                        .foregroundColor(.orange.opacity(0.3))
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: lockSize))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        Text("\(setNum)회")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(cs == .dark ? .white : .black)
                        VStack(spacing: 5) {
                            ProgressView(value: prog)
                                .progressViewStyle(.linear)
                                .tint(unlocked ? Color.examYellow : .orange)
                                .frame(width: min(geo.size.width * 0.55, 280))
                            Text(String(format: "%.0f%%", prog * 100))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(cs == .dark ? .white.opacity(0.75) : .black.opacity(0.6))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: max(geo.size.height * 0.44, 260))
                }
                .buttonStyle(.plain)
                
                if setNum < 3 { Divider().background(Color.gray.opacity(0.3)) }
            }
        }
    }

    // MARK: - Audio Player Panel

    private var audioPlayerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(Color.examYellow).frame(width: 4)
                Text("음  성")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.examYellow)
                    .kerning(2).padding(.leading, 10)
                Spacer()
                if isPlaying {
                    HStack(spacing: 3) {
                        ForEach(0..<3) { i in
                            RoundedRectangle(cornerRadius: 1).fill(Color.examYellow)
                                .frame(width: 3, height: CGFloat([6, 10, 7][i]))
                                .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.13),
                                           value: isPlaying)
                        }
                    }
                    .padding(.trailing, 14)
                }
            }
            .frame(height: 22).padding(.top, 12)

            GeometryReader { g in
                let width = max(g.size.width, 1)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.examBorder(cs).opacity(0.30))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.examYellow.opacity(0.75))
                        .frame(width: width * CGFloat(audioProgress), height: 4)
                        .animation(.linear(duration: 0.1), value: audioProgress)
                    Circle()
                        .fill(Color.examYellow)
                        .frame(width: 10, height: 10)
                        .offset(x: width * CGFloat(audioProgress) - 5)
                        .animation(.linear(duration: 0.1), value: audioProgress)
                }
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            guard let player = audioPlayer else { return }
                            let x = min(max(0, value.location.x), width)
                            let ratio = Double(x / width)
                            let (start, end): (Double, Double) = {
                                if let s = currentQuestion?.startTime, let e = currentQuestion?.endTime, e > s {
                                    return (s, e)
                                }
                                return (0, player.duration)
                            }()
                            let duration = max(end - start, 0.0001)
                            let newTime = start + ratio * duration
                            player.currentTime = min(max(newTime, start), end)
                            audioProgress = Float((player.currentTime - start) / duration)
                            if isPlaying { startProgressUpdateTimer(); setupEndTimeTimer() }
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = min(max(0, value.location.x), width)
                            let ratio = Double(x / width)
                            let (start, end): (Double, Double) = {
                                if let s = currentQuestion?.startTime, let e = currentQuestion?.endTime, e > s {
                                    return (s, e)
                                }
                                if let d = audioPlayer?.duration { return (0, d) }
                                return (0, 1)
                            }()
                            _ = max(end - start, 0.0001)

                            if !isScrubbing {
                                wasPlayingBeforeScrub = isPlaying
                                if isPlaying { audioPlayer?.pause() }
                                updateTimer?.invalidate(); updateTimer = nil
                                endTimeTimer?.invalidate(); endTimeTimer = nil
                                isScrubbing = true
                            }
                            audioProgress = Float(min(max(ratio, 0.0), 1.0))
                        }
                        .onEnded { value in
                            guard let player = audioPlayer else { isScrubbing = false; return }
                            let x = min(max(0, value.location.x), width)
                            let ratio = Double(x / width)
                            let (start, end): (Double, Double) = {
                                if let s = currentQuestion?.startTime, let e = currentQuestion?.endTime, e > s {
                                    return (s, e)
                                }
                                return (0, player.duration)
                            }()
                            let duration = max(end - start, 0.0001)
                            let newTime = start + ratio * duration
                            player.currentTime = min(max(newTime, start), end)
                            audioProgress = Float((player.currentTime - start) / duration)

                            if wasPlayingBeforeScrub {
                                player.play(); isPlaying = true
                                startProgressUpdateTimer(); setupEndTimeTimer()
                            } else {
                                isPlaying = false
                            }
                            wasPlayingBeforeScrub = false
                            isScrubbing = false
                        }
                )
            }
            .frame(height: 10)
            
            HStack {
                Text(formatTime(audioProgress: audioProgress))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(cs == .dark ? .white.opacity(0.45) : .black.opacity(0.35))
                Spacer()
                Text(totalDurationText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(cs == .dark ? .white.opacity(0.45) : .black.opacity(0.35))
            }
            .padding(.horizontal, 14).padding(.top, 10)

            HStack(spacing: 12) {
                Button { togglePlayPause() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill").font(.system(size: 13, weight: .medium))
                        Text(isPlaying ? "일시정지" : "재  생").font(.system(size: 12, weight: .medium)).kerning(isPlaying ? 0 : 2)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.examYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Button { restartCurrentAudio() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 13, weight: .medium))
                        Text("처음부터").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(cs == .dark ? .white.opacity(0.65) : Color.examBorder(cs))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.examCard(cs))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.examBorder(cs), lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 14)
        }
        .background(Color.examCard(cs))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.examBorder(cs), lineWidth: 1.5))
        .overlay(alignment: .topLeading) {
            Rectangle().fill(Color.examYellow).frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    // MARK: - Single Question View

    @ViewBuilder
    private func singleQuestionView(q: AudioQuestion, geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            questionBox(text: q.question, imageName: q.imageName, geometry: geometry)
            audioPlayerPanel
            if showAnswer && hasScript { scriptPanel }
            examOptions(q: q)
        }
    }

    // MARK: - Question Box

    @ViewBuilder
    private func questionBox(text: String, imageName: String?, geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Rectangle().fill(Color.examYellow).frame(width: 4)
                Text("문  제").font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.examYellow).kerning(2).padding(.leading, 10)
                Spacer()
            }
            .frame(height: 18)
            
            Text(text)
                .font(.custom("Hiragino Sans", size: 16 * fontScale, relativeTo: .body))
                .foregroundColor(cs == .dark ? .white.opacity(0.88) : Color(red: 0.08, green: 0.06, blue: 0.12))
                .lineSpacing(8).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
            
            if let name = imageName, let img = UIImage(named: name) {
                Image(uiImage: img).resizable().scaledToFit()
                    .frame(maxWidth: geometry.size.width * 0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture { showFullscreenImage = true }
            }
        }
        .padding(14)
        .background(Color.examCard(cs))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.examBorder(cs), lineWidth: 1.5))
        .overlay(alignment: .topLeading) {
            Rectangle().fill(Color.examYellow).frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    // MARK: - Exam Options (①②③④)

    @ViewBuilder
    private func examOptions(q: AudioQuestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(q.options.enumerated()), id: \.offset) { idx, option in
                let isCorrect = showAnswer && option == q.answer
                let isWrong   = showAnswer && option == selectedAnswer && option != q.answer
                let isDimmed  = showAnswer && !isCorrect && !isWrong

                Button { selectAnswer(option) } label: {
                    HStack(alignment: .top, spacing: 0) {
                        Text(option)
                            .font(.custom("Hiragino Sans", size: 15 * fontScale, relativeTo: .body))
                            .foregroundColor(
                                isCorrect ? Color.green :
                                isWrong   ? Color.red   :
                                isDimmed  ? (cs == .dark ? .white.opacity(0.28) : .black.opacity(0.26)) :
                                cs == .dark ? .white.opacity(0.88)
                                           : Color(red: 0.08, green: 0.06, blue: 0.12))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .background(isCorrect ? Color.green.opacity(0.06) :
                                isWrong   ? Color.red.opacity(0.05)   : Color.clear)
                    .contentShape(Rectangle())
                    .overlay(alignment: .trailing) {
                        HStack(spacing: 0) {
                            if isCorrect {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            } else if isWrong {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.trailing, 12)
                    }
                }
                .disabled(showAnswer).buttonStyle(.plain)

                if idx < q.options.count - 1 {
                    Rectangle().fill(Color.examBorder(cs).opacity(0.22))
                        .frame(height: 1).padding(.horizontal, 12)
                }
            }
        }
        .background(Color.examCard(cs))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.examBorder(cs), lineWidth: 1.5))
    }

    // MARK: - Script Panel

    private var scriptPanel: some View {
        VStack(spacing: 0) {
            Button {
                if isScriptEntitled {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showScript.toggle() }
                } else { showPurchaseView = true }
            } label: {
                HStack(spacing: 10) {
                    Text("스크립트")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(isScriptEntitled
                                    ? Color(red: 0.52, green: 0.37, blue: 0.06)
                                    : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    if !isScriptEntitled {
                        Text("구독 필요").font(.system(size: 12, weight: .medium)).foregroundColor(.orange)
                    }
                    Spacer()
                    if isScriptEntitled {
                        Image(systemName: showScript ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(cs == .dark ? Color.examGold.opacity(0.7) : Color.examGold)
                    } else {
                        Image(systemName: "lock.fill").foregroundColor(.orange).font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(cs == .dark ? Color(red: 0.18, green: 0.15, blue: 0.07)
                                        : Color(red: 1.0, green: 0.97, blue: 0.88))
            }
            .buttonStyle(.plain)

            if showScript && isScriptEntitled {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle().fill(Color.examGold.opacity(0.35)).frame(height: 1)
                    if !currentScriptText.isEmpty {
                        Text(currentScriptText)
                            .font(.custom("Hiragino Sans", size: 13 * fontScale, relativeTo: .body))
                            .foregroundColor(cs == .dark ? .white.opacity(0.82)
                                                        : Color(red: 0.15, green: 0.12, blue: 0.04))
                            .lineSpacing(7).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle").foregroundColor(.secondary).font(.system(size: 14))
                            Text("스크립트가 없습니다.").font(.system(size: 14)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center).padding(14)
                    }
                }
                .background(cs == .dark ? Color(red: 0.14, green: 0.12, blue: 0.05)
                                        : Color(red: 1.0, green: 0.98, blue: 0.92))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4)
            .stroke(Color.examGold.opacity(cs == .dark ? 0.45 : 0.55), lineWidth: 1.5))
    }

    // MARK: - Next Button

    private var nextButton: some View {
        Button { moveToNextQuestion() } label: {
            HStack(spacing: 8) {
                Spacer()
                Text(currentQuestionIndex < totalQuestionsCount - 1 ? "다음 문제" : "완료")
                    .font(.system(size: 15 * fontScale, weight: .medium))
                    .foregroundColor(cs == .dark ? .white.opacity(0.85) : Color.examYellow)
                    .padding(.vertical, 14)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(cs == .dark ? .white.opacity(0.5) : Color.examYellow.opacity(0.7))
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.examCard(cs))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(Color.examYellow.opacity(cs == .dark ? 0.55 : 0.75), lineWidth: 1.5))
        }
    }

    // MARK: - Result Sheet

    private var resultSheet: some View {
        let totalQ   = totalQuestionsCount
        let correct  = score
        let wrong    = totalQ - correct
        let accuracy = totalQ > 0 ? Int(Double(correct) / Double(totalQ) * 100) : 0

        return ZStack {
            Color.examPaper(cs).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 6) {
                    Text("JLPT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.examYellow).kerning(2)
                    Text("채 점 결 과")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(cs == .dark ? .white : .black).kerning(5)
                }
                .padding(.bottom, 28)

                VStack(spacing: 3) {
                    Rectangle().fill(Color.examYellow).frame(height: 2)
                    Rectangle().fill(Color.examYellow.opacity(0.25)).frame(height: 1)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 18) {
                    resultRow(label: "정  답", value: "\(correct)", color: Color(red: 0.15, green: 0.55, blue: 0.20))
                    Divider()
                    resultRow(label: "오  답", value: "\(wrong)",   color: Color(red: 0.65, green: 0.10, blue: 0.12))
                    Divider()
                    resultRow(label: "정답률", value: "\(accuracy)％", color: Color.examYellow)
                }
                .padding(.vertical, 28).padding(.horizontal, 36)

                VStack(spacing: 3) {
                    Rectangle().fill(Color.examYellow.opacity(0.25)).frame(height: 1)
                    Rectangle().fill(Color.examYellow).frame(height: 2)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Button {
                        if let set = selectedSet {
                            DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group3_set\(set)")
                            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group3_set\(set)", index: 0)
                            currentQuestionIndex = 0; selectedAnswer = nil; showAnswer = false
                            progress = 0; score = 0; audioProgress = 0; isPlaying = false
                            showScript = false; wrongAnswers = []; isRetryMode = false
                            selectedSet = nil; audioQuestions = []
                        }
                        stopAudio(); showResultSheet = false; dismiss()
                    } label: {
                        Text("완료")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.examYellow)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    if !isRetryMode && !wrongAnswers.isEmpty {
                        Button {
                            stopAudio(); audioPlayer = nil
                            currentQuestionIndex = 0; selectedAnswer = nil; showAnswer = false
                            score = 0; audioProgress = 0; isPlaying = false; showScript = false
                            isRetryMode = true; progress = 0
                            showResultSheet = false
                            setupAudio()
                        } label: {
                            Text("틀린 문제만 다시 풀기")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color(red: 0.52, green: 0.37, blue: 0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .padding(.horizontal, 32).padding(.top, 24)
                Spacer()
            }
            .frame(maxWidth: 400)
        }
    }

    private func resultRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: 15, weight: .medium))
                .foregroundColor(cs == .dark ? .white.opacity(0.60) : .black.opacity(0.55)).kerning(2)
            Spacer()
            Text(value).font(.system(size: 30, weight: .bold, design: .monospaced)).foregroundColor(color)
        }
    }

    // MARK: - Time Helpers

    private func formatTime(audioProgress: Float) -> String {
        guard let player = audioPlayer else { return "0:00" }
        let duration: Double
        if let s = currentQuestion?.startTime, let e = currentQuestion?.endTime, e > s { duration = e - s }
        else { duration = player.duration }
        let elapsed = Double(audioProgress) * duration
        return String(format: "%d:%02d", Int(elapsed) / 60, Int(elapsed) % 60)
    }
    
    private var totalDurationText: String {
        guard let player = audioPlayer else { return "0:00" }
        let duration: Double
        if let s = currentQuestion?.startTime, let e = currentQuestion?.endTime, e > s { duration = e - s }
        else { duration = player.duration }
        return String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60)
    }

    // MARK: - Logic (기존 로직 100% 동일 유지)

    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer; showAnswer = true
        if answer == currentQuestion?.answer {
            score += 1
        } else if !isRetryMode {
            let idx = currentQuestionIndex
            if !wrongAnswers.contains(idx) { wrongAnswers.append(idx) }
        }
        if !isScriptEntitled { showScript = false }
    }
    
    private func moveToNextQuestion() {
        // Gating: Non-subscribers can solve up to Q3 in Set 1 only (JLPT 기존 로직 유지)
        if !storeManager.isPremium, selectedSet == 1 {
            // currentQuestionIndex is zero-based; Q1=0, Q2=1, Q3=2. Prevent moving from Q3 to Q4.
            if currentQuestionIndex >= 2 {
                showPurchaseView = true
                return
            }
        }

        if currentQuestionIndex < totalQuestionsCount - 1 {
            stopAudio(); audioPlayer = nil
            currentQuestionIndex += 1
            selectedAnswer = nil; showAnswer = false; showScript = false
            audioProgress = 0; isPlaying = false
            setupAudio(); refreshSetProgress()
        } else {
            showResultSheet = true
        }
    }
    
    private func resetToFirstQuestion() {
        stopAudio(); audioPlayer = nil
        currentQuestionIndex = 0; progress = 0; score = 0
        selectedAnswer = nil; showAnswer = false; audioProgress = 0
        isPlaying = false; showScript = false; wrongAnswers = []; isRetryMode = false
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
        currentQuestionIndex = 0; selectedAnswer = nil; showAnswer = false
        progress = 0; score = 0; audioProgress = 0; isPlaying = false
        showScript = false; selectedSet = nil; audioQuestions = []
        wrongAnswers = []; isRetryMode = false; isTabBarHidden = false
        stopAudio(); dismiss()
    }

    // MARK: - Audio (기존 로직 유지)

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
        } catch { print("오디오 세션 설정 실패: \(error.localizedDescription)") }
    }
    
    private func restartCurrentAudio() {
        guard let player = audioPlayer, let question = currentQuestion else { return }
        if let start = question.startTime, let end = question.endTime, end > start {
            player.currentTime = start; setupEndTimeTimer()
        } else {
            player.currentTime = 0; endTimeTimer?.invalidate()
        }
        player.play(); isPlaying = true
    }

    private func loadQuestionsForSet(_ set: Int) {
        audioQuestions = AudioDataLoader.load(set: set)
        let savedIndex = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group3_set\(set)")
        currentQuestionIndex = (savedIndex < audioQuestions.count) ? savedIndex : 0
        progress = audioQuestions.isEmpty ? 0 : Double(currentQuestionIndex) / Double(audioQuestions.count)
        selectedAnswer = nil; showAnswer = false; audioProgress = 0
        isPlaying = false; wrongAnswers = []; isRetryMode = false
        stopAudio(); setupAudio()
    }

    private func refreshSetProgress() {
        func prog(set: Int, group: String) -> Double {
            let qs = AudioDataLoader.load(set: set)
            let s  = DatabaseManager.shared.loadProgress(level: level, quizGroup: group)
            return qs.isEmpty ? 0 : Double(min(s, max(qs.count - 1, 0))) / Double(max(qs.count, 1))
        }
        // 1~3회 세트 진행도
        set1Progress = prog(set: 1, group: "Group3_set1")
        set2Progress = prog(set: 2, group: "Group3_set2")
        set3Progress = prog(set: 3, group: "Group3_set3")
    }

    private func setupAudio() {
        guard let question = currentQuestion else { return }
        let localizedFromCSV = question.localizedScript()
        let script: String?
        if let csvScript = localizedFromCSV, !csvScript.isEmpty { script = csvScript }
        else { script = ScriptData.getScript(for: question.audioFileName) }
        currentScriptText = script ?? ""; hasScript = (script != nil)
        
        guard let url = Bundle.main.url(forResource: question.audioFileName, withExtension: nil) else {
            print("오디오 파일을 찾을 수 없습니다: \(question.audioFileName)"); return
        }
        do {
            configureAudioSession()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            if let start = question.startTime, let end = question.endTime, end > start {
                audioPlayer?.currentTime = start; setupEndTimeTimer()
            } else {
                audioPlayer?.currentTime = 0; endTimeTimer?.invalidate()
            }
            let delegate = AudioPlayerDelegate(isPlaying: $isPlaying)
            _delegate = delegate; audioPlayer?.delegate = delegate
            startProgressUpdateTimer(); setupEndTimeTimer()
        } catch { print("오디오 플레이어 초기화 실패: \(error.localizedDescription)") }
    }
    
    private func setupEndTimeTimer() {
        endTimeTimer?.invalidate(); endTimeTimer = nil
        guard let question = currentQuestion, let player = audioPlayer,
              let startTime = question.startTime, let endTime = question.endTime,
              endTime > startTime else { return }
        if player.currentTime < startTime { player.currentTime = startTime }
        let remainingTime = endTime - player.currentTime
        if remainingTime > 0 {
            endTimeTimer = Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { _ in
                self.stopAudioAtEndTime()
            }
        }
    }
    
    private func stopAudioAtEndTime() {
        audioPlayer?.pause(); isPlaying = false
        if let startTime = currentQuestion?.startTime { audioPlayer?.currentTime = startTime }
    }
    
    private func startProgressUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = self.audioPlayer, let question = self.currentQuestion else { return }
            if let startTime = question.startTime, let endTime = question.endTime, endTime > startTime {
                let duration = endTime - startTime
                let currentOffset = player.currentTime - startTime
                self.audioProgress = duration > 0 ? Float(max(0, min(currentOffset / duration, 1.0))) : 0
                if player.currentTime >= endTime { self.stopAudioAtEndTime() }
            } else {
                self.audioProgress = player.duration > 0 ? Float(player.currentTime / player.duration) : 0
                if !player.isPlaying && player.currentTime >= player.duration {
                    self.isPlaying = false; self.updateTimer?.invalidate()
                }
            }
            self.isPlaying = player.isPlaying
        }
    }

    private func togglePlayPause() {
        guard let player = audioPlayer, let question = currentQuestion else { return }
        if player.isPlaying {
            player.pause(); isPlaying = false; endTimeTimer?.invalidate()
        } else {
            if let startTime = question.startTime, let endTime = question.endTime {
                if player.currentTime < startTime || player.currentTime >= endTime {
                    player.currentTime = startTime
                }
            } else if player.currentTime >= player.duration { player.currentTime = 0 }
            player.play(); isPlaying = true; startProgressUpdateTimer(); setupEndTimeTimer()
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        if let startTime = currentQuestion?.startTime { audioPlayer?.currentTime = startTime }
        else { audioPlayer?.currentTime = 0 }
        updateTimer?.invalidate(); updateTimer = nil
        endTimeTimer?.invalidate(); endTimeTimer = nil
        isPlaying = false
    }
}

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    @Binding var isPlaying: Bool
    init(isPlaying: Binding<Bool>) { self._isPlaying = isPlaying }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.isPlaying = false }
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { self.isPlaying = false }
        print("오디오 디코딩 에러: \(error?.localizedDescription ?? "알 수 없음")")
    }
}

