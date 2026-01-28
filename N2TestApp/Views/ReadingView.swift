import SwiftUI
import AVFoundation
import StoreKit

// Color extensions for custom colors
extension Color {
    static let lightGray = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let darkGray = Color(red: 0.2, green: 0.2, blue: 0.2)
}

struct ReadingView: View {
    @Binding var isTabBarHidden: Bool
    
    @State private var currentQuestionIndex = 0
    @State private var progress: Double = 0
    @State private var score: Int = 0
    @State private var selectedAnswer: String?
    @State private var showAnswer = false
    @State private var showFullscreenImage = false
    @State private var showNextQuestion = false
    @State private var showMenu = false
    @State private var isSpeaking = false
    @State private var fontScale: CGFloat = 1.2
    @State private var showResultSheet = false
    @StateObject private var interstitialViewModel = InterstitialViewModel()
    @State private var wrongAnswers: [Int] = []
    @State private var isRetryMode = false
    
    @State private var showPurchaseView = false
    @State private var isFromResult: Bool = false
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var selectedSet: Int? = nil
    @State private var questions: [Question] = []
    @State private var set1Progress: Double = 0
    @State private var set2Progress: Double = 0
    @State private var set3Progress: Double = 0
    @State private var set4Progress: Double = 0
    @State private var set5Progress: Double = 0
    @State private var set6Progress: Double = 0
    @State private var set7Progress: Double = 0
    @State private var set8Progress: Double = 0
    
    @ObservedObject private var appAdManager = AppAdManager.shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private let level: String = "Topik1"
    private var quizGroup: String { "Group1_set\(selectedSet ?? 0)" }
    private let synthesizer = AVSpeechSynthesizer()
    
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
    
    private var currentQuestion: Question {
        guard !questions.isEmpty else {
            return Question(question: "", options: [], answer: "")
        }
        if isRetryMode && !wrongAnswers.isEmpty {
            let wrongIndex = wrongAnswers[currentQuestionIndex]
            return questions[wrongIndex]
        }
        return questions[currentQuestionIndex]
    }
    
    private var totalQuestionsCount: Int {
        isRetryMode ? wrongAnswers.count : questions.count
    }
    
    func applyUnderline(to text: String, underlinedWords: [String]) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: text)
        for word in underlinedWords {
            var range = (text as NSString).range(of: word)
            while range.location != NSNotFound {
                attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                attributedText.addAttribute(.underlineColor, value: UIColor.red, range: range)
                let nextRangeLocation = range.location + range.length
                range = (text as NSString).range(of: word, options: [], range: NSRange(location: nextRangeLocation, length: text.count - nextRangeLocation))
            }
        }
        return attributedText
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
                                                    Label("처음부터 다시", systemImage: "arrow.counterclockwise")
                                                }
                                                
                                                Button(action: {
                                                    if let set = selectedSet, !isRetryMode {
                                                        DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: currentQuestionIndex)
                                                    }
                                                    selectedSet = nil
                                                    currentQuestionIndex = 0
                                                    selectedAnswer = nil
                                                    showAnswer = false
                                                    progress = 0
                                                    wrongAnswers = []
                                                    isRetryMode = false
                                                }) {
                                                    Label("회차 선택", systemImage: "list.number")
                                                }
                                                
                                                Button(action: {
                                                    dismiss()
                                                }) {
                                                    Label("메인 화면으로", systemImage: "house.fill")
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
                                            if !questions.isEmpty {
                                                let q = currentQuestion
                                                if let questionText = q.question, !questionText.isEmpty {
                                                    Text(AttributedString(applyUnderline(to: questionText, underlinedWords: q.underline)))
                                                        .font(.custom("Hiragino Sans", size: 22 * fontScale, relativeTo: .body))
                                                        .multilineTextAlignment(.center)
                                                        .padding(.horizontal, 20)
                                                        .frame(maxWidth: .infinity)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                }
                                                
                                                if let imageName = q.imageName {
                                                    Image(imageName)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(maxWidth: geometry.size.width * 0.8)
                                                        .onTapGesture {
                                                            showFullscreenImage = true
                                                        }
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
                                        
                                        // 선택지 버튼
                                        VStack(spacing: 16) {
                                            ForEach(currentQuestion.options, id: \.self) { option in
                                                Button(action: {
                                                    selectAnswer(option)
                                                }) {
                                                    HStack {
                                                        Spacer()
                                                        Text(AttributedString(applyUnderline(to: option, underlinedWords: currentQuestion.underline)))
                                                            .font(.custom("Hiragino Sans", size: 18 * fontScale, relativeTo: .body))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                            .multilineTextAlignment(.center)
                                                            .padding(.vertical, 12)
                                                            .fixedSize(horizontal: false, vertical: true)
                                                        Spacer()
                                                        if showAnswer {
                                                            if option == currentQuestion.answer {
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
                                                                .fill(Color.blue.opacity(0.15))
                                                                .frame(width: min(geo.size.width * 0.35, 200), height: min(geo.size.width * 0.35, 200))
                                                            
                                                            Image(systemName: "book.fill")
                                                                .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                .foregroundColor(.blue)
                                                        }
                                                        
                                                        Text("1회")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)

                                                        VStack(spacing: 6) {
                                                            ProgressView(value: set1Progress)
                                                                .progressViewStyle(.linear)
                                                                .tint(.blue)
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
                                            ForEach([
                                                (2, set2Progress)
                                            ], id: \.0) { setNumber, progress in
                                                VStack(spacing: 0) {
                                                    Spacer()
                                                    Button(action: {
                                                        if storeManager.isSubscribed {
                                                            selectedSet = setNumber
                                                            loadQuestionsForSet(setNumber)
                                                        } else {
                                                            isFromResult = false
                                                            showPurchaseView = true
                                                        }
                                                    }) {
                                                        VStack(spacing: 16) {
                                                            ZStack {
                                                                RoundedRectangle(cornerRadius: 20)
                                                                    .fill((storeManager.isSubscribed ? Color.blue : Color.orange).opacity(0.15))
                                                                    .frame(width: min(geo.size.width * 0.35, 200), height: min(geo.size.width * 0.35, 200))
                                                                
                                                                if storeManager.isSubscribed {
                                                                    Image(systemName: "book.fill")
                                                                        .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                        .foregroundColor(.blue)
                                                                } else {
                                                                    ZStack {
                                                                        Image(systemName: "book.fill")
                                                                            .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                            .foregroundColor(.orange.opacity(0.3))
                                                                        
                                                                        Image(systemName: "lock.fill")
                                                                            .font(.system(size: min(geo.size.width * 0.08, 40)))
                                                                            .foregroundColor(.orange)
                                                                    }
                                                                }
                                                            }
                                                            
                                                            Text("\(setNumber)회")
                                                                .font(.system(size: 24, weight: .bold))
                                                                .foregroundColor(colorScheme == .dark ? .white : .black)

                                                            VStack(spacing: 6) {
                                                                ProgressView(value: progress)
                                                                    .progressViewStyle(.linear)
                                                                    .tint(storeManager.isSubscribed ? .blue : .orange)
                                                                    .frame(width: min(geo.size.width * 0.5, 260))
                                                                Text(String(format: "%.0f%%", progress * 100))
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
                                            }
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
            if let imageName = currentQuestion.imageName,
               let image = UIImage(named: imageName) {
                FullscreenImageView(image: image) {
                    showFullscreenImage = false
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
                        currentQuestionIndex = 0
                        selectedAnswer = nil
                        showAnswer = false
                        score = 0
                        isRetryMode = true
                        progress = 0
                        showResultSheet = false
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
            if let set = selectedSet, !isRetryMode {
                let saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set\(set)")
                currentQuestionIndex = (saved < questions.count) ? saved : 0
                progress = Double(currentQuestionIndex) / Double(max(questions.count, 1))
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
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: currentQuestionIndex)
            }
            refreshSetProgress()
            synthesizer.stopSpeaking(at: .immediate)
        }
        .onChange(of: currentQuestionIndex) { _, newValue in
            if let set = selectedSet, !isRetryMode {
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: newValue)
            }
            progress = Double(newValue) / Double(totalQuestionsCount)
            refreshSetProgress()
        }
    }
    
    private func selectAnswer(_ answer: String) {
        selectedAnswer = answer
        showAnswer = true
        
        if answer == currentQuestion.answer {
            score += 1
        } else {
            if !isRetryMode {
                let actualIndex = currentQuestionIndex
                if !wrongAnswers.contains(actualIndex) {
                    wrongAnswers.append(actualIndex)
                }
            }
        }
    }
    
    private func moveToNextQuestion() {
        if currentQuestionIndex < totalQuestionsCount - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil
            showAnswer = false
            refreshSetProgress()
            
            // 광고
            if currentQuestionIndex == 2 && !appAdManager.hasShownReadingAd && !isRetryMode {
                Task {
                    await interstitialViewModel.loadAd()
                    if interstitialViewModel.isAdReady {
                        interstitialViewModel.showAd()
                        appAdManager.hasShownReadingAd = true
                    }
                }
            }
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
            DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group1_set\(set)")
            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: 0)
            
            currentQuestionIndex = 0
            selectedAnswer = nil
            showAnswer = false
            progress = 0
            score = 0
            wrongAnswers = []
            isRetryMode = false
            
            selectedSet = nil
            questions = []
        }
        showResultSheet = false
        dismiss()
    }

    private func loadQuestionsForSet(_ set: Int) {
        questions = DataLoader.load(set: set)

        let savedIndex = DatabaseManager.shared.loadProgress(
            level: level,
            quizGroup: "Group1_set\(set)"
        )

        currentQuestionIndex = (savedIndex < questions.count) ? savedIndex : 0
        progress = Double(currentQuestionIndex) / Double(max(questions.count, 1))

        selectedAnswer = nil
        showAnswer = false
        wrongAnswers = []
        isRetryMode = false
    }

    
    private func refreshSetProgress() {
        let set1Questions = DataLoader.load(set: 1)
        let set1Saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set1")
        set1Progress = set1Questions.isEmpty ? 0 : Double(min(set1Saved, max(set1Questions.count - 1, 0))) / Double(max(set1Questions.count, 1))
        
        let set2Questions = DataLoader.load(set: 2)
        let set2Saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set2")
        set2Progress = set2Questions.isEmpty ? 0 : Double(min(set2Saved, max(set2Questions.count - 1, 0))) / Double(max(set2Questions.count, 1))
    }
    
    private func resetToFirstQuestion() {
        currentQuestionIndex = 0
        progress = 0
        score = 0
        selectedAnswer = nil
        showAnswer = false
        wrongAnswers = []
        isRetryMode = false
        DatabaseManager.shared.resetProgress(level: level, quizGroup: quizGroup)
        if let set = selectedSet {
            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: 0)
        }
    }
    
    private func resetAndDismiss() {
        if let set = selectedSet {
            DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group1_set\(set)")
        }
        
        currentQuestionIndex = 0
        selectedAnswer = nil
        showAnswer = false
        progress = 0
        score = 0
        selectedSet = nil
        questions = []
        wrongAnswers = []
        isRetryMode = false
        isTabBarHidden = false
        dismiss()
    }
}
