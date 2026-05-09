import SwiftUI
import AVFoundation
import StoreKit

// Color extensions for custom colors
extension Color {
    static let lightGray = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let darkGray  = Color(red: 0.2, green: 0.2, blue: 0.2)
}

struct ReadingView: View {
    @Binding var isTabBarHidden: Bool

    // MARK: - 기존 단일 문제 상태 (retry 모드 전용)
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswer: String?
    @State private var showAnswer = false
    @State private var showExplanation = false

    // MARK: - 그룹 모드 상태 (일반 모드)
    /// questions 로드 후 passageGroup 기준으로 구성된 그룹 배열
    @State private var questionGroups: [QuestionGroup] = []
    /// 현재 표시 중인 그룹 인덱스
    @State private var currentGroupIndex: Int = 0
    /// 그룹 내 각 문제의 선택 답안 [Question.id: selectedOption]
    @State private var groupAnswers: [UUID: String] = [:]
    /// 그룹 내 해설 표시 여부 [Question.id]
    @State private var groupShowExplanation: Set<UUID> = []

    // MARK: - 공통 상태
    @State private var progress: Double = 0
    @State private var score: Int = 0
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
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var selectedSet: Int? = nil
    @State private var questions: [Question] = []
    @State private var set1Progress: Double = 0
    @State private var set2Progress: Double = 0
    @State private var set3Progress: Double = 0
    @State private var set4Progress: Double = 0

    @ObservedObject private var appAdManager = AppAdManager.shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let level: String = "Topik1"
    private var quizGroup: String { "Group1_set\(selectedSet ?? 0)" }
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Computed: 현재 그룹 (일반 모드)
    private var currentGroup: QuestionGroup? {
        guard !questionGroups.isEmpty, currentGroupIndex < questionGroups.count else { return nil }
        return questionGroups[currentGroupIndex]
    }

    // MARK: - Computed: 현재 문제 (retry 모드 전용)
    private var currentQuestion: Question {
        guard !questions.isEmpty else { return Question(question: "", options: [], answer: "") }
        return questions[wrongAnswers[currentQuestionIndex]]
    }

    // MARK: - 잠금 여부
    private var isCurrentQuestionLocked: Bool {
        guard let set = selectedSet else { return false }
        if storeManager.isPremium { return false }
        return set != 1
    }

    // MARK: - 해설 권한 (문제 인덱스 기반)
    private func explanationEntitled(for questionIndex: Int) -> Bool {
        if storeManager.isPremium { return true }
        if let set = selectedSet, set == 1, questionIndex <= 4 { return true }
        return false
    }

    /// 현재 그룹의 첫 번째 문제 인덱스로 해설 권한 판단
    private var isExplanationEntitled: Bool {
        if storeManager.isPremium { return true }
        if isRetryMode {
            return explanationEntitled(for: wrongAnswers[currentQuestionIndex])
        }
        let firstIdx = currentGroup?.questionIndices.first ?? currentGroupIndex
        return explanationEntitled(for: firstIdx)
    }

    private var bannerHeight: CGFloat {
        if horizontalSizeClass == .regular && verticalSizeClass == .compact      { return 90  }
        else if horizontalSizeClass == .regular                                   { return 100 }
        else if horizontalSizeClass == .compact && verticalSizeClass == .compact  { return 32  }
        else                                                                       { return 50  }
    }

    // MARK: - 전체 문제 수 (retry: 틀린 문제 수 / 일반: 전체 문제 수)
    private var totalQuestionsCount: Int {
        isRetryMode ? wrongAnswers.count : questions.count
    }

    private var totalGroupCount: Int {
        isRetryMode ? wrongAnswers.count : questionGroups.count
    }

    // MARK: - Underline 적용
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

    // MARK: - Body
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
                                        // MARK: 메뉴
                                        HStack {
                                            Menu {
                                                Button(action: { resetToFirstQuestion() }) {
                                                    Label("처음부터 다시", systemImage: "arrow.counterclockwise")
                                                }
                                                Button(action: {
                                                    if let set = selectedSet, !isRetryMode {
                                                        DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: currentGroupIndex)
                                                    }
                                                    selectedSet = nil
                                                    currentGroupIndex = 0
                                                    currentQuestionIndex = 0
                                                    groupAnswers = [:]
                                                    groupShowExplanation = []
                                                    selectedAnswer = nil
                                                    showAnswer = false
                                                    showExplanation = false
                                                    progress = 0
                                                    wrongAnswers = []
                                                    isRetryMode = false
                                                }) {
                                                    Label("회차 선택", systemImage: "list.number")
                                                }
                                                Button(action: { dismiss() }) {
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

                                        // MARK: 문제 표시 영역
                                        if !questions.isEmpty {
                                            if isRetryMode {
                                                // ── retry: 단일 문제 UI ─────────────────────────
                                                singleQuestionContent(
                                                    question: currentQuestion,
                                                    questionIndex: wrongAnswers[currentQuestionIndex],
                                                    selectedOpt: selectedAnswer,
                                                    isAnswered: showAnswer,
                                                    showExpl: showExplanation,
                                                    geoWidth: geometry.size.width,
                                                    onSelect: { opt in selectAnswerRetry(opt) },
                                                    onNext: { moveToNextQuestion() },
                                                    onToggleExpl: { showExplanation.toggle() },
                                                    isExplEntitled: isExplanationEntitled,
                                                    isLastQuestion: currentQuestionIndex >= totalQuestionsCount - 1
                                                )
                                            } else if let group = currentGroup {
                                                if group.isMulti {
                                                    // ── 다중 문제 그룹 UI ──────────────────────
                                                    multiGroupContent(group: group, geoWidth: geometry.size.width)
                                                } else {
                                                    // ── 단일 문제 그룹 UI ──────────────────────
                                                    let q = group.questions[0]
                                                    let qIdx = group.questionIndices[0]
                                                    singleQuestionContent(
                                                        question: q,
                                                        questionIndex: qIdx,
                                                        selectedOpt: groupAnswers[q.id],
                                                        isAnswered: groupAnswers[q.id] != nil,
                                                        showExpl: groupShowExplanation.contains(q.id),
                                                        geoWidth: geometry.size.width,
                                                        onSelect: { opt in selectAnswerInGroup(question: q, questionIndex: qIdx, answer: opt) },
                                                        onNext: { moveToNextGroup() },
                                                        onToggleExpl: {
                                                            if groupShowExplanation.contains(q.id) {
                                                                groupShowExplanation.remove(q.id)
                                                            } else {
                                                                groupShowExplanation.insert(q.id)
                                                            }
                                                        },
                                                        isExplEntitled: explanationEntitled(for: qIdx),
                                                        isLastQuestion: currentGroupIndex >= totalGroupCount - 1
                                                    )
                                                }
                                            }
                                        }

                                        Spacer()
                                    }
                                    .frame(minHeight: availableHeight)
                                    .padding(.vertical)
                                }
                            }
                        } else {
                            // MARK: 세트 선택 화면
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
                                            // ── 1회 세트 ──────────────────────────
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
                                                            VStack(spacing: 4) {
                                                                Image(systemName: "book.fill")
                                                                    .font(.system(size: min(geo.size.width * 0.13, 70)))
                                                                    .foregroundColor(.blue)
                                                            }
                                                        }
                                                        Text("1회")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        VStack(spacing: 6) {
                                                            ProgressView(value: set1Progress)
                                                                .progressViewStyle(.linear).tint(.blue)
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

                                            // ── 2회 세트 ──────────────────────────
                                            let set2Unlocked = storeManager.isPremium
                                            VStack(spacing: 0) {
                                                Spacer()
                                                Button(action: {
                                                    if set2Unlocked {
                                                        selectedSet = 2
                                                        loadQuestionsForSet(2)
                                                    } else {
                                                        showPurchaseView = true
                                                    }
                                                }) {
                                                    VStack(spacing: 16) {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill((set2Unlocked ? Color.blue : Color.orange).opacity(0.15))
                                                                .frame(width: min(geo.size.width * 0.35, 200), height: min(geo.size.width * 0.35, 200))
                                                            if set2Unlocked {
                                                                Image(systemName: "book.fill")
                                                                    .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                    .foregroundColor(.blue)
                                                            } else {
                                                                VStack(spacing: 8) {
                                                                    Image(systemName: "crown.fill")
                                                                        .font(.system(size: min(geo.size.width * 0.10, 50)))
                                                                        .foregroundColor(.orange)
                                                                    Text("구독 필요")
                                                                        .font(.system(size: 12, weight: .bold))
                                                                        .foregroundColor(.orange)
                                                                        .padding(.horizontal, 8)
                                                                        .padding(.vertical, 3)
                                                                        .background(Color.orange.opacity(0.15))
                                                                        .cornerRadius(6)
                                                                }
                                                            }
                                                        }
                                                        Text("2회")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        VStack(spacing: 6) {
                                                            ProgressView(value: set2Progress)
                                                                .progressViewStyle(.linear)
                                                                .tint(set2Unlocked ? .blue : .orange)
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

                                            Divider()
                                                .background(colorScheme == .dark ? Color.gray : Color.gray.opacity(0.3))

                                            // ── 3회 세트 ──────────────────────────
                                            let set3Unlocked = storeManager.isPremium
                                            VStack(spacing: 0) {
                                                Spacer()
                                                Button(action: {
                                                    if set3Unlocked {
                                                        selectedSet = 3
                                                        loadQuestionsForSet(3)
                                                    } else {
                                                        showPurchaseView = true
                                                    }
                                                }) {
                                                    VStack(spacing: 16) {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill((set3Unlocked ? Color.blue : Color.orange).opacity(0.15))
                                                                .frame(width: min(geo.size.width * 0.35, 200), height: min(geo.size.width * 0.35, 200))
                                                            if set3Unlocked {
                                                                Image(systemName: "book.fill")
                                                                    .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                    .foregroundColor(.blue)
                                                            } else {
                                                                VStack(spacing: 8) {
                                                                    Image(systemName: "crown.fill")
                                                                        .font(.system(size: min(geo.size.width * 0.10, 50)))
                                                                        .foregroundColor(.orange)
                                                                    Text("구독 필요")
                                                                        .font(.system(size: 12, weight: .bold))
                                                                        .foregroundColor(.orange)
                                                                        .padding(.horizontal, 8)
                                                                        .padding(.vertical, 3)
                                                                        .background(Color.orange.opacity(0.15))
                                                                        .cornerRadius(6)
                                                                }
                                                            }
                                                        }
                                                        Text("3회")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        VStack(spacing: 6) {
                                                            ProgressView(value: set3Progress)
                                                                .progressViewStyle(.linear)
                                                                .tint(set3Unlocked ? .blue : .orange)
                                                                .frame(width: min(geo.size.width * 0.5, 260))
                                                            Text(String(format: "%.0f%%", set3Progress * 100))
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


                                            // ── 4회 세트 ──────────────────────────
                                            let set4Unlocked = storeManager.isPremium
                                            VStack(spacing: 0) {
                                                Spacer()
                                                Button(action: {
                                                    if set4Unlocked {
                                                        selectedSet = 4
                                                        loadQuestionsForSet(4)
                                                    } else {
                                                        showPurchaseView = true
                                                    }
                                                }) {
                                                    VStack(spacing: 16) {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill((set4Unlocked ? Color.blue : Color.orange).opacity(0.15))
                                                                .frame(width: min(geo.size.width * 0.35, 200), height: min(geo.size.width * 0.35, 200))
                                                            if set4Unlocked {
                                                                Image(systemName: "book.fill")
                                                                    .font(.system(size: min(geo.size.width * 0.15, 80)))
                                                                    .foregroundColor(.blue)
                                                            } else {
                                                                VStack(spacing: 8) {
                                                                    Image(systemName: "crown.fill")
                                                                        .font(.system(size: min(geo.size.width * 0.10, 50)))
                                                                        .foregroundColor(.orange)
                                                                    Text("구독 필요")
                                                                        .font(.system(size: 12, weight: .bold))
                                                                        .foregroundColor(.orange)
                                                                        .padding(.horizontal, 8)
                                                                        .padding(.vertical, 3)
                                                                        .background(Color.orange.opacity(0.15))
                                                                        .cornerRadius(6)
                                                                }
                                                            }
                                                        }
                                                        Text("4회")
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                                        VStack(spacing: 6) {
                                                            ProgressView(value: set4Progress)
                                                                .progressViewStyle(.linear)
                                                                .tint(set4Unlocked ? .blue : .orange)
                                                                .frame(width: min(geo.size.width * 0.5, 260))
                                                            Text(String(format: "%.0f%%", set4Progress * 100))
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    AdaptiveBottomBannerView()
                }
            }
        }
        .ignoresSafeArea(.container, edges: [.leading, .trailing])
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $showFullscreenImage) {
            // 현재 표시 중인 이미지 이름 결정
            let imageName: String? = {
                if isRetryMode { return currentQuestion.imageName }
                return currentGroup?.sharedImageName
            }()
            if let name = imageName, let image = UIImage(named: name) {
                FullscreenImageView(image: image) { showFullscreenImage = false }
            }
        }
        .fullScreenCover(isPresented: $showPurchaseView) {
            PurchaseView()
        }
        .fullScreenCover(isPresented: $showResultSheet) {
            let correctCount = score
            let wrongCount   = totalQuestionsCount - score
            let accuracy     = totalQuestionsCount > 0 ? Int(Double(score) / Double(totalQuestionsCount) * 100) : 0
            VStack(spacing: 24) {
                Text("퀴즈 결과").font(.largeTitle).fontWeight(.bold)
                Text("✔️ 정답수: \(correctCount)").font(.title2).foregroundColor(.green)
                Text("❌ 오답수: \(wrongCount)").font(.title2).foregroundColor(.red)
                Text("📊 정답률: \(accuracy)%").font(.title2).foregroundColor(.blue)

                Button(action: {
                    if let set = selectedSet {
                        DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group1_set\(set)")
                        DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: 0)
                        currentGroupIndex = 0
                        currentQuestionIndex = 0
                        groupAnswers = [:]
                        groupShowExplanation = []
                        selectedAnswer = nil; showAnswer = false
                        showExplanation = false; progress = 0; score = 0
                        wrongAnswers = []; isRetryMode = false
                        selectedSet = nil; questions = []; questionGroups = []
                    }
                    showResultSheet = false
                    dismiss()
                }) {
                    Text("확인").font(.title3).padding().frame(maxWidth: .infinity)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(10)
                }

                if !isRetryMode && !wrongAnswers.isEmpty {
                    Button(action: {
                        currentQuestionIndex = 0; selectedAnswer = nil; showAnswer = false
                        showExplanation = false; score = 0; isRetryMode = true; progress = 0
                        showResultSheet = false
                    }) {
                        Text("틀린 문제만 다시 풀기").font(.title3).padding().frame(maxWidth: .infinity)
                            .background(Color.orange).foregroundColor(.white).cornerRadius(10)
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
                currentGroupIndex = (saved < questionGroups.count) ? saved : 0
                progress = Double(currentGroupIndex) / Double(max(questionGroups.count, 1))
            } else {
                currentGroupIndex = 0; progress = 0
            }
            refreshSetProgress()
        }
        .onDisappear {
            isTabBarHidden = false
            if let set = selectedSet, !isRetryMode {
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: currentGroupIndex)
            }
            refreshSetProgress()
            synthesizer.stopSpeaking(at: .immediate)
        }
        .onChange(of: currentGroupIndex) { _, newValue in
            if let set = selectedSet, !isRetryMode {
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: newValue)
            }
            progress = Double(newValue) / Double(max(totalGroupCount, 1))
            refreshSetProgress()
        }
        .onChange(of: currentQuestionIndex) { _, newValue in
            // retry 모드에서 진행률 업데이트
            if isRetryMode {
                progress = Double(newValue) / Double(max(totalQuestionsCount, 1))
            }
        }
    }

    // MARK: - 단일 문제 뷰 (retry 모드 + 단일 그룹 공용)
    @ViewBuilder
    private func singleQuestionContent(
        question q: Question,
        questionIndex qIdx: Int,
        selectedOpt: String?,
        isAnswered: Bool,
        showExpl: Bool,
        geoWidth: CGFloat,
        onSelect: @escaping (String) -> Void,
        onNext: @escaping () -> Void,
        onToggleExpl: @escaping () -> Void,
        isExplEntitled: Bool,
        isLastQuestion: Bool
    ) -> some View {
        VStack(alignment: .center, spacing: 24) {
            // ── 지문/질문 박스 ────────────────────────────────────
            VStack(alignment: .center, spacing: 8) {
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
                        .frame(maxWidth: geoWidth * 0.8)
                        .onTapGesture { showFullscreenImage = true }
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

            // ── 해설 버튼 (정답 확인 후) ──────────────────────────
            if isAnswered {
                explanationPanel(
                    question: q,
                    showExpl: showExpl,
                    isEntitled: isExplEntitled,
                    onToggle: onToggleExpl
                )
                .padding(.horizontal, 20)
            }

            // ── 선택지 + 다음 버튼 ───────────────────────────────
            VStack(spacing: 16) {
                ForEach(q.options, id: \.self) { option in
                    Button(action: { onSelect(option) }) {
                        HStack {
                            Spacer()
                            Text(AttributedString(applyUnderline(to: option, underlinedWords: q.underline)))
                                .font(.custom("Hiragino Sans", size: 18 * fontScale, relativeTo: .body))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 12)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            if isAnswered {
                                if option == q.answer {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green).padding(.trailing, 8)
                                } else if option == selectedOpt {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red).padding(.trailing, 8)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(optionBackground(option: option, answer: q.answer, selected: selectedOpt, isAnswered: isAnswered))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(optionBorder(option: option, answer: q.answer, selected: selectedOpt, isAnswered: isAnswered), lineWidth: isAnswered ? 2 : 1)
                        )
                    }
                    .disabled(isAnswered)
                }

                if isAnswered {
                    nextButton(label: isLastQuestion ? "완료" : "다음 문제", action: onNext)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 다중 문제 그룹 뷰
    @ViewBuilder
    private func multiGroupContent(group: QuestionGroup, geoWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            // ── 공유 지문 박스 ────────────────────────────────────
            VStack(alignment: .center, spacing: 8) {
                if let passage = group.sharedPassage, !passage.isEmpty {
                    Text(AttributedString(applyUnderline(to: passage, underlinedWords: group.sharedUnderline)))
                        .font(.custom("Hiragino Sans", size: 20 * fontScale, relativeTo: .body))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let imageName = group.sharedImageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: geoWidth * 0.8)
                        .onTapGesture { showFullscreenImage = true }
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

            // ── 각 문항 ───────────────────────────────────────────
            // 묶음 문제 전체 완료 여부: 모든 문제를 풀어야 해설 일괄 해금
            let allAnswered = group.questions.allSatisfy { groupAnswers[$0.id] != nil }

            ForEach(Array(group.questions.enumerated()), id: \.element.id) { idx, q in
                let qIdx     = group.questionIndices[idx]
                let selOpt   = groupAnswers[q.id]
                let answered = selOpt != nil
                let showExpl = groupShowExplanation.contains(q.id)
                let entitled = explanationEntitled(for: qIdx)

                VStack(alignment: .leading, spacing: 16) {
                    // 문항 번호 + 질문 텍스트
                    VStack(alignment: .leading, spacing: 8) {
                        // 문항 번호 뱃지
                        Text("問 \(idx + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.85))
                            .clipShape(Capsule())

                        // 문항 질문 (subQuestion 우선, 없으면 question)
                        let questionText = q.subQuestion ?? q.question ?? ""
                        if !questionText.isEmpty {
                            Text(AttributedString(applyUnderline(to: questionText, underlinedWords: q.underline)))
                                .font(.custom("Hiragino Sans", size: 18 * fontScale, relativeTo: .body))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 20)

                    // 해설 버튼: 묶음 문제 전체 완료 후 일괄 해금
                    if allAnswered {
                        explanationPanel(
                            question: q,
                            showExpl: showExpl,
                            isEntitled: entitled,
                            onToggle: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if showExpl { groupShowExplanation.remove(q.id) }
                                    else        { groupShowExplanation.insert(q.id) }
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                    }

                    // 선택지
                    VStack(spacing: 12) {
                        ForEach(q.options, id: \.self) { option in
                            Button(action: {
                                selectAnswerInGroup(question: q, questionIndex: qIdx, answer: option)
                            }) {
                                HStack {
                                    Spacer()
                                    Text(AttributedString(applyUnderline(to: option, underlinedWords: q.underline)))
                                        .font(.custom("Hiragino Sans", size: 17 * fontScale, relativeTo: .body))
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .multilineTextAlignment(.center)
                                        .padding(.vertical, 11)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    if answered {
                                        if option == q.answer {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green).padding(.trailing, 8)
                                        } else if option == selOpt {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red).padding(.trailing, 8)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(optionBackground(option: option, answer: q.answer, selected: selOpt, isAnswered: answered))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(optionBorder(option: option, answer: q.answer, selected: selOpt, isAnswered: answered), lineWidth: answered ? 2 : 1)
                                )
                            }
                            .disabled(answered)
                        }
                    }
                    .padding(.horizontal, 20)

                    // 문항 구분선 (마지막 문항 제외)
                    if idx < group.questions.count - 1 {
                        Divider()
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    }
                }
            }

            // ── 모든 문항 답변 완료 시 다음 그룹 버튼 ────────────
            if allAnswered {
                nextButton(
                    label: currentGroupIndex >= totalGroupCount - 1 ? "완료" : "다음 문제",
                    action: { moveToNextGroup() }
                )
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - 해설 패널 (재사용)
    @ViewBuilder
    private func explanationPanel(
        question: Question,
        showExpl: Bool,
        isEntitled: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                if isEntitled {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        onToggle()
                    }
                } else {
                    showPurchaseView = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isEntitled ? "lightbulb.fill" : "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isEntitled ? .yellow : .orange)
                    Text(LocalizedStringKey("explanation.button_title"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if isEntitled {
                        Image(systemName: showExpl ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                    } else {
                        Text(LocalizedStringKey("explanation.subscribe_hint"))
                            .font(.system(size: 12, weight: .medium)).foregroundColor(.orange)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: showExpl && isEntitled ? 0 : 12, style: .continuous)
                        .fill(colorScheme == .dark
                              ? Color(red: 0.14, green: 0.14, blue: 0.20)
                              : Color(red: 0.93, green: 0.96, blue: 1.0))
                )
                .clipShape(
                    .rect(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: showExpl && isEntitled ? 0 : 12,
                        bottomTrailingRadius: showExpl && isEntitled ? 0 : 12,
                        topTrailingRadius: 12
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEntitled ? Color.blue.opacity(0.4) : Color.orange.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if showExpl && isEntitled {
                VStack(alignment: .leading, spacing: 10) {
                    if let text = question.localizedExplanation {
                        Text(text)
                            .font(.custom("Hiragino Sans", size: 15 * fontScale, relativeTo: .body))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.85))
                            .lineSpacing(5).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle").foregroundColor(.secondary).font(.system(size: 14))
                            Text(LocalizedStringKey("explanation.not_available")).font(.system(size: 14)).foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(colorScheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.17) : Color(red: 0.96, green: 0.98, blue: 1.0))
                .clipShape(.rect(topLeadingRadius: 0, bottomLeadingRadius: 12, bottomTrailingRadius: 12, topTrailingRadius: 0))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.25), lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - 다음 버튼 (재사용)
    @ViewBuilder
    private func nextButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                Text(label)
                    .font(.system(size: 18))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.vertical, 12)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.darkGray : Color.lightGray))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color.darkGray, lineWidth: 1))
        }
    }

    // MARK: - 선택지 색상 헬퍼
    private func optionBackground(option: String, answer: String, selected: String?, isAnswered: Bool) -> Color {
        guard isAnswered else {
            return colorScheme == .dark ? Color.darkGray : Color.lightGray
        }
        if option == answer {
            return Color.green.opacity(0.15)
        } else if option == selected {
            return Color.red.opacity(0.12)
        }
        return colorScheme == .dark ? Color.darkGray : Color.lightGray
    }

    private func optionBorder(option: String, answer: String, selected: String?, isAnswered: Bool) -> Color {
        guard isAnswered else { return Color.darkGray }
        if option == answer { return Color.green.opacity(0.7) }
        if option == selected { return Color.red.opacity(0.6) }
        return Color.darkGray
    }

    // MARK: - Private Functions

    /// retry 모드: 단일 문제 답 선택
    private func selectAnswerRetry(_ answer: String) {
        selectedAnswer = answer
        showAnswer = true
        if answer == currentQuestion.answer {
            score += 1
        }
        // retry에서는 추가 오답 기록 없음
    }

    /// 일반 모드: 그룹 내 문제 답 선택
    private func selectAnswerInGroup(question: Question, questionIndex: Int, answer: String) {
        guard groupAnswers[question.id] == nil else { return } // 이미 답한 문제
        groupAnswers[question.id] = answer
        if answer == question.answer {
            score += 1
        } else {
            if !wrongAnswers.contains(questionIndex) {
                wrongAnswers.append(questionIndex)
            }
        }
    }

    /// retry 모드: 다음 문제로 이동
    private func moveToNextQuestion() {
        if !storeManager.isPremium, selectedSet == 1 {
            if currentQuestionIndex >= 2 {
                showPurchaseView = true
                return
            }
        }

        if currentQuestionIndex < totalQuestionsCount - 1 {
            currentQuestionIndex += 1
            selectedAnswer = nil; showAnswer = false; showExplanation = false
            refreshSetProgress()
        } else {
            showResultSheet = true
        }
    }

    /// 일반 모드: 다음 그룹으로 이동
    private func moveToNextGroup() {
        if !storeManager.isPremium, selectedSet == 1 {
            if currentGroupIndex >= 2 {
                showPurchaseView = true
                return
            }
        }

        if currentGroupIndex < questionGroups.count - 1 {
            currentGroupIndex += 1
            groupAnswers = [:]
            groupShowExplanation = []
            refreshSetProgress()
        } else {
            showResultSheet = true
        }
    }

    private func loadQuestionsForSet(_ set: Int) {
        questions = DataLoader.load(set: set)
        questionGroups = DataLoader.groupQuestions(questions)

        let savedIndex = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set\(set)")
        currentGroupIndex = (savedIndex < questionGroups.count) ? savedIndex : 0
        currentQuestionIndex = 0

        progress = Double(currentGroupIndex) / Double(max(questionGroups.count, 1))
        groupAnswers = [:]
        groupShowExplanation = []
        selectedAnswer = nil; showAnswer = false; showExplanation = false
        wrongAnswers = []; isRetryMode = false
    }

    private func refreshSetProgress() {
        let q1 = DataLoader.load(set: 1)
        let s1 = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set1")
        let g1 = DataLoader.groupQuestions(q1)
        set1Progress = g1.isEmpty ? 0 : Double(min(s1, max(g1.count - 1, 0))) / Double(max(g1.count, 1))

        let q2 = DataLoader.load(set: 2)
        let s2 = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set2")
        let g2 = DataLoader.groupQuestions(q2)
        set2Progress = g2.isEmpty ? 0 : Double(min(s2, max(g2.count - 1, 0))) / Double(max(g2.count, 1))

        let q3 = DataLoader.load(set: 3)
        let s3 = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set3")
        let g3 = DataLoader.groupQuestions(q3)
        set3Progress = g3.isEmpty ? 0 : Double(min(s3, max(g3.count - 1, 0))) / Double(max(g3.count, 1))

        let q4 = DataLoader.load(set: 4)
        let s4 = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set4")
        let g4 = DataLoader.groupQuestions(q4)
        set4Progress = g4.isEmpty ? 0 : Double(min(s4, max(g4.count - 1, 0))) / Double(max(g4.count, 1))
    }

    private func resetToFirstQuestion() {
        currentGroupIndex = 0
        currentQuestionIndex = 0
        progress = 0; score = 0
        groupAnswers = [:]
        groupShowExplanation = []
        selectedAnswer = nil; showAnswer = false; showExplanation = false
        wrongAnswers = []; isRetryMode = false
        DatabaseManager.shared.resetProgress(level: level, quizGroup: quizGroup)
        if let set = selectedSet {
            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: 0)
        }
    }

    private func resetAndDismiss() {
        if let set = selectedSet {
            DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group1_set\(set)")
        }
        currentGroupIndex = 0; currentQuestionIndex = 0
        groupAnswers = [:]; groupShowExplanation = []
        selectedAnswer = nil; showAnswer = false
        showExplanation = false; progress = 0; score = 0
        selectedSet = nil; questions = []; questionGroups = []
        wrongAnswers = []; isRetryMode = false
        isTabBarHidden = false
        dismiss()
    }
}
