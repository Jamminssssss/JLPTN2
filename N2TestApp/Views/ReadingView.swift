// ReadingView.swift — EXAM PAPER REDESIGN
// Preserves 100% of JLPT logic, state, and functionality
// UI structurally matches TopikReadingView (Exam style, Blue tokens)

import SwiftUI
import AVFoundation
import StoreKit
import UIKit

// MARK: - Exam Colour Tokens (TOPIK 스타일 파랑 계열 적용)

private extension Color {
    static func examPaper(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.09, green: 0.09, blue: 0.10)
                   : Color(red: 0.95, green: 0.94, blue: 0.97)
    }
    static func examCard(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.13, green: 0.13, blue: 0.16)
                   : Color(red: 0.993, green: 0.990, blue: 0.998)
    }
    static func examBorder(_ s: ColorScheme) -> Color {
        s == .dark ? Color(red: 0.28, green: 0.28, blue: 0.38)
                   : Color(red: 0.52, green: 0.50, blue: 0.65)
    }
    /// TOPIK 파랑 (시험 느낌)
    static var examBlue: Color { Color(red: 0.09, green: 0.26, blue: 0.68) }
    /// 해설 골드
    static var examGold: Color { Color(red: 0.78, green: 0.58, blue: 0.12) }
    /// 새 그린 토큰
    static var examGreen: Color { Color(red: 0.98, green: 0.80, blue: 0.10) }
    
    // Fallback colors for safety if needed
    static let lightGray = Color(red: 0.9, green: 0.9, blue: 0.9)
    static let darkGray  = Color(red: 0.2, green: 0.2, blue: 0.2)
}

// MARK: - ReadingView

struct ReadingView: View {
    @Binding var isTabBarHidden: Bool

    @State private var selectedAnswer: String?
    @State private var showAnswer = false
    @State private var showExplanation = false

    // MARK: - 그룹 모드 상태
    @State private var questionGroups:       [QuestionGroup] = []
    @State private var currentGroupIndex:    Int             = 0
    @State private var groupAnswers:         [UUID: String]  = [:]
    @State private var groupShowExplanation: Set<UUID>       = []

    // MARK: - 공통 상태
    @State private var progress:          Double  = 0
    @State private var score:             Int     = 0
    @State private var showFullscreenImage = false
    @State private var showNextQuestion   = false
    @State private var showMenu           = false
    @State private var isSpeaking         = false
    @State private var fontScale:          CGFloat = 1.2
    @State private var showResultSheet    = false
    @State private var showPurchaseView   = false

    @StateObject private var storeManager        = StoreKitManager.shared
    @StateObject private var interstitialViewModel = InterstitialViewModel()

    @State private var selectedSet: Int? = nil
    @State private var questions:   [Question] = []

    @State private var set1Progress: Double = 0
    @State private var set2Progress: Double = 0
    @State private var set3Progress: Double = 0

    @ObservedObject private var appAdManager = AppAdManager.shared

    @Environment(\.dismiss)             private var dismiss
    @Environment(\.colorScheme)         private var colorScheme
    @Environment(\.scenePhase)          private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass)   private var verticalSizeClass

    private let level:   String = "JLPTN2"
    private var quizGroup: String { "Group1_set\(selectedSet ?? 0)" }
    private let synthesizer = AVSpeechSynthesizer()
    private var cs: ColorScheme { colorScheme }

    // MARK: - Derived

    private var currentGroup: QuestionGroup? {
        guard !questionGroups.isEmpty, currentGroupIndex < questionGroups.count else { return nil }
        return questionGroups[currentGroupIndex]
    }
    
    private var totalQuestionsCount: Int { questions.count }
    private var totalGroupCount:     Int { questionGroups.count }

    private var isCurrentQuestionLocked: Bool {
        guard let set = selectedSet else { return false }
        if storeManager.isPremium { return false }
        return set != 1
    }

    // MARK: - Underline Helper

    func applyUnderline(to text: String, underlinedWords: [String]) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        for word in underlinedWords {
            var range = (text as NSString).range(of: word)
            while range.location != NSNotFound {
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                // TOPIK 스타일에 맞춰 밑줄 색상 변경
                attributed.addAttribute(.underlineColor, value: UIColor.systemBlue, range: range)
                let next = range.location + range.length
                guard next < text.count else { break }
                range = (text as NSString).range(of: word, options: [], range: NSRange(location: next, length: text.count - next))
            }
        }
        return attributed
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
                                            if !questions.isEmpty {
                                                if let group = currentGroup {
                                                    if group.isMulti {
                                                        multiGroupContent(group: group, geoWidth: geometry.size.width)
                                                    } else {
                                                        let q    = group.questions[0]
                                                        let qIdx = group.questionIndices[0]
                                                        singleQuestionContent(
                                                            question:       q,
                                                            questionIndex:  qIdx,
                                                            selectedOpt:    groupAnswers[q.id],
                                                            isAnswered:     groupAnswers[q.id] != nil,
                                                            showExpl:       groupShowExplanation.contains(q.id),
                                                            geoWidth:       geometry.size.width,
                                                            onSelect:       { selectAnswerInGroup(question: q, questionIndex: qIdx, answer: $0) },
                                                            onNext:         { moveToNextGroup() },
                                                            onToggleExpl: {
                                                                if groupShowExplanation.contains(q.id) { groupShowExplanation.remove(q.id) }
                                                                else { groupShowExplanation.insert(q.id) }
                                                            },
                                                            isExplEntitled: explanationEntitled(for: qIdx),
                                                            isLastQuestion: currentGroupIndex >= totalGroupCount - 1
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .frame(minHeight: inner.size.height - 64)
                                    }
                                }
                            }

                        } else {
                            // MARK: 세트 선택 화면 (TOPIK 스타일)
                            Color.examPaper(cs).ignoresSafeArea()
                            GeometryReader { geo in
                                VStack(spacing: 0) {
                                    HStack {
                                        Button { dismiss() } label: {
                                            Image(systemName: "chevron.left")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(cs == .dark ? .white : .black)
                                                .padding()
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    ScrollView {
                                        // 3개 세트만 전달
                                        setSelectionGrid(geo: geo, maxSets: 3,
                                                         progresses: [set1Progress, set2Progress, set3Progress],
                                                         icon: "book.fill",
                                                         unlockedColor: Color.examGreen)
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
            let imageName = currentGroup?.sharedImageName
            if let name = imageName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let image = UIImage(named: name) {
                FullscreenImageView(image: image) { showFullscreenImage = false }
            } else {
                Color.clear.onAppear { showFullscreenImage = false }
            }
        }
        .fullScreenCover(isPresented: $showPurchaseView) {
            PurchaseView()
        }
        .fullScreenCover(isPresented: $showResultSheet) { resultSheet }
        .onAppear {
            isTabBarHidden = true
            if let set = selectedSet {
                let saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set\(set)")
                currentGroupIndex = saved < questionGroups.count ? saved : 0
                progress = Double(currentGroupIndex) / Double(max(questionGroups.count, 1))
            } else {
                currentGroupIndex = 0; progress = 0
            }
            refreshSetProgress()
        }
        .onDisappear {
            isTabBarHidden = false
            if let set = selectedSet {
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: currentGroupIndex)
            }
            refreshSetProgress()
            synthesizer.stopSpeaking(at: .immediate)
        }
        .onChange(of: currentGroupIndex) { _, newValue in
            if let set = selectedSet {
                DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: newValue)
            }
            progress = Double(newValue) / Double(max(totalGroupCount, 1))
            refreshSetProgress()
        }
        // CloudKit 복원 시 갱신
        .onReceive(NotificationCenter.default.publisher(for: .jlptCloudRestoreCompleted)) { _ in
            if let set = selectedSet {
                let saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set\(set)")
                currentGroupIndex = saved < questionGroups.count ? saved : 0
                progress = Double(currentGroupIndex) / Double(max(questionGroups.count, 1))
            }
            refreshSetProgress()
        }
    }

    // MARK: - Exam Header  ──────────────────────────────────────────────────

    private var examHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Menu {
                    Button { resetToFirstQuestion() } label: {
                        Label("처음부터 다시", systemImage: "arrow.counterclockwise")
                    }
                    Button {
                        if let set = selectedSet {
                            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: currentGroupIndex)
                        }
                        selectedSet = nil; currentGroupIndex = 0
                        groupAnswers = [:]; groupShowExplanation = []; selectedAnswer = nil
                        showAnswer = false; showExplanation = false; progress = 0
                    } label: { Label("회차 선택", systemImage: "list.number") }
                    Button { dismiss() } label: {
                        Label("메인 화면으로", systemImage: "house.fill")
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
                        .foregroundColor(Color.examGreen)
                        .kerning(1.5)
                    Text("読  解")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(cs == .dark ? .white.opacity(0.45) : .black.opacity(0.40))
                        .kerning(4)
                }

                Spacer()

                Text("\(currentGroupIndex + 1)／\(max(totalGroupCount, 1))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(cs == .dark ? .white.opacity(0.5) : .black.opacity(0.45))
                    .frame(width: 60, alignment: .trailing)
                    .padding(.trailing, 16)
            }
            .frame(height: 50)

            VStack(spacing: 3) {
                Rectangle().fill(Color.examGreen).frame(height: 2)
                Rectangle().fill(Color.examGreen.opacity(0.25)).frame(height: 1)
            }
        }
        .background(Color.examCard(cs))
    }

    // MARK: - Progress Bar  ─────────────────────────────────────────────────

    private var examProgressBar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Color.examBorder(cs).opacity(0.18)
                Color.examGreen.opacity(0.65)
                    .frame(width: g.size.width *
                           CGFloat(currentGroupIndex + 1) /
                           CGFloat(max(totalGroupCount, 1)))
                    .animation(.easeInOut(duration: 0.3), value: currentGroupIndex)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Set Selection Grid  ───────────────────────────────────────────

    @ViewBuilder
    private func setSelectionGrid(geo: GeometryProxy, maxSets: Int,
                                   progresses: [Double],
                                   icon: String, unlockedColor: Color) -> some View {
        let iconSize: CGFloat = min(geo.size.width * 0.22, 100)
        let lockSize: CGFloat = iconSize * 0.45
        VStack(spacing: 0) {
            ForEach(1...maxSets, id: \.self) { setNum in
                let unlocked = storeManager.isPremium || setNum == 1
                let prog     = setNum <= progresses.count ? progresses[setNum - 1] : 0.0

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
                                .fill((unlocked ? unlockedColor : Color.orange).opacity(0.13))
                                .frame(width: iconSize * 1.6, height: iconSize * 1.6)
                            if unlocked {
                                Image(systemName: icon)
                                    .font(.system(size: iconSize))
                                    .foregroundColor(unlockedColor)
                            } else {
                                ZStack {
                                    Image(systemName: icon)
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
                                .tint(unlocked ? unlockedColor : .orange)
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
                if setNum < maxSets { Divider().background(Color.gray.opacity(0.3)) }
            }
        }
    }

    // MARK: - Single Question  ──────────────────────────────────────────────

    @ViewBuilder
    private func singleQuestionContent(
        question:       Question,
        questionIndex:  Int,
        selectedOpt:    String?,
        isAnswered:     Bool,
        showExpl:       Bool,
        geoWidth:       CGFloat,
        onSelect:       @escaping (String) -> Void,
        onNext:         @escaping () -> Void,
        onToggleExpl:   @escaping () -> Void,
        isExplEntitled: Bool,
        isLastQuestion: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            // 지문 박스
            if let qText = question.question, !qText.isEmpty {
                passageBox(text: qText, underline: question.underline,
                           imageName: question.imageName, geoWidth: geoWidth)
            } else if question.imageName != nil {
                passageBox(text: nil, underline: question.underline,
                           imageName: question.imageName, geoWidth: geoWidth)
            }

            // 해설 (답한 후)
            if isAnswered {
                explanationPanel(question: question, showExpl: showExpl,
                                 isEntitled: isExplEntitled, onToggle: onToggleExpl)
            }

            // 선택지
            examOptions(question: question, selectedOpt: selectedOpt,
                        isAnswered: isAnswered, onSelect: onSelect)

            // 다음 버튼
            if isAnswered {
                nextButton(label: isLastQuestion ? "완료" : "다음 문제", action: onNext)
            }
        }
    }

    // MARK: - Multi Group  ──────────────────────────────────────────────────

    @ViewBuilder
    private func multiGroupContent(group: QuestionGroup, geoWidth: CGFloat) -> some View {
        let allAnswered = group.questions.allSatisfy { groupAnswers[$0.id] != nil }

        VStack(alignment: .leading, spacing: 16) {

            // 공유 지문
            if let passage = group.sharedPassage, !passage.isEmpty {
                passageBox(text: passage, underline: group.sharedUnderline,
                           imageName: group.sharedImageName, geoWidth: geoWidth)
            }

            // 소문항
            ForEach(Array(group.questions.enumerated()), id: \.element.id) { idx, q in
                let qIdx     = group.questionIndices[idx]
                let selOpt   = groupAnswers[q.id]
                let answered = selOpt != nil
                let showExpl = groupShowExplanation.contains(q.id)
                let entitled = explanationEntitled(for: qIdx)

                VStack(alignment: .leading, spacing: 12) {

                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(Color.examGreen).frame(width: 22, height: 22)
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 1)

                        let subText = q.subQuestion ?? q.question ?? ""
                        if !subText.isEmpty {
                            Text(AttributedString(applyUnderline(to: subText, underlinedWords: q.underline)))
                                .font(.custom("Hiragino Sans", // Japanese Font Preserved
                                              size: 14 * fontScale, relativeTo: .body))
                                .foregroundColor(cs == .dark ? .white : .black.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }

                    if allAnswered {
                        explanationPanel(question: q, showExpl: showExpl, isEntitled: entitled) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if showExpl { groupShowExplanation.remove(q.id) }
                                else        { groupShowExplanation.insert(q.id) }
                            }
                        }
                    }

                    examOptions(question: q, selectedOpt: selOpt, isAnswered: answered,
                                onSelect: { selectAnswerInGroup(question: q, questionIndex: qIdx, answer: $0) })

                    if idx < group.questions.count - 1 {
                        Rectangle().fill(Color.examBorder(cs).opacity(0.35))
                            .frame(height: 1).padding(.top, 4)
                    }
                }
            }

            if allAnswered {
                nextButton(
                    label:  currentGroupIndex >= totalGroupCount - 1 ? "완료" : "다음 문제",
                    action: { moveToNextGroup() }
                )
            }
        }
    }

    // MARK: - Passage Box  ──────────────────────────────────────────────────

    @ViewBuilder
    private func passageBox(text: String?, underline: [String],
                             imageName: String?, geoWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                Rectangle().fill(Color.examGreen).frame(width: 4)
                Text("지  문")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.examGreen)
                    .kerning(2)
                    .padding(.leading, 10)
                Spacer()
            }
            .frame(height: 18)

            if let t = text, !t.isEmpty {
                Text(AttributedString(applyUnderline(to: t, underlinedWords: underline)))
                    .font(.custom("Hiragino Sans", // Japanese Font Preserved
                                  size: 15 * fontScale, relativeTo: .body))
                    .foregroundColor(cs == .dark ? .white.opacity(0.88) : Color(red: 0.08, green: 0.06, blue: 0.12))
                    .lineSpacing(9)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }

            if let name = imageName,
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               UIImage(named: name) != nil {
                Image(name)
                    .resizable().scaledToFit()
                    .frame(maxWidth: geoWidth * 0.85)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture { showFullscreenImage = true }
            }
        }
        .padding(14)
        .background(Color.examCard(cs))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.examBorder(cs), lineWidth: 1.5))
        .overlay(alignment: .topLeading) {
            Rectangle().fill(Color.examGreen).frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    // MARK: - Exam Options  ─────────────────────────────────────────

    @ViewBuilder
    private func examOptions(question: Question, selectedOpt: String?,
                              isAnswered: Bool, onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(question.options.enumerated()), id: \.offset) { idx, option in
                let isCorrect = isAnswered && option == question.answer
                let isWrong   = isAnswered && option == selectedOpt && option != question.answer
                let isDimmed  = isAnswered && !isCorrect && !isWrong

                Button { onSelect(option) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(AttributedString(applyUnderline(to: option, underlinedWords: question.underline)))
                            .font(.custom("Hiragino Sans", // Japanese Font Preserved
                                          size: 14 * fontScale, relativeTo: .body))
                            .foregroundColor(
                                isCorrect ? Color.green :
                                isWrong   ? Color.red   :
                                isDimmed  ? (cs == .dark ? .white.opacity(0.28) : .black.opacity(0.26)) :
                                cs == .dark ? .white.opacity(0.88)
                                           : Color(red: 0.08, green: 0.06, blue: 0.12))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .background(
                        isCorrect ? Color.green.opacity(0.06) :
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
                .disabled(isAnswered)
                .buttonStyle(.plain)

                if idx < question.options.count - 1 {
                    Rectangle().fill(Color.examBorder(cs).opacity(0.22))
                        .frame(height: 1).padding(.horizontal, 12)
                }
            }
        }
        .background(Color.examCard(cs))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.examBorder(cs), lineWidth: 1.5))
    }

    // MARK: - Explanation Panel (해설)  ────────────────────────────────────

    @ViewBuilder
    private func explanationPanel(question: Question, showExpl: Bool,
                                   isEntitled: Bool, onToggle: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button {
                if isEntitled {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { onToggle() }
                } else { showPurchaseView = true }
            } label: {
                HStack(spacing: 10) {
                    Text("해  설")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .kerning(2)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(isEntitled
                                    ? Color(red: 0.52, green: 0.37, blue: 0.06)
                                    : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    if !isEntitled {
                        Text(LocalizedStringKey("explanation.subscribe_hint"))
                            .font(.system(size: 12, weight: .medium)).foregroundColor(.orange)
                    }
                    Spacer()
                    if isEntitled {
                        Image(systemName: showExpl ? "chevron.up" : "chevron.down")
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

            if showExpl && isEntitled {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle().fill(Color.examGold.opacity(0.35)).frame(height: 1)
                    if let text = question.localizedExplanation {
                        Text(text)
                            .font(.custom("Hiragino Sans", // Japanese Font Preserved
                                          size: 13 * fontScale, relativeTo: .body))
                            .foregroundColor(cs == .dark ? .white.opacity(0.82)
                                                        : Color(red: 0.15, green: 0.12, blue: 0.04))
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(14)
                    } else {
                        HStack {
                            Image(systemName: "info.circle").foregroundColor(.secondary)
                            Text(LocalizedStringKey("explanation.not_available"))
                                .foregroundColor(.secondary).font(.system(size: 13))
                        }
                        .padding(14)
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

    // MARK: - Next Button  ──────────────────────────────────────────────────

    @ViewBuilder
    private func nextButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Spacer()
                Text(label)
                    .font(.custom("Hiragino Sans", size: 14 * fontScale, relativeTo: .body))
                    .foregroundColor(cs == .dark ? .white.opacity(0.85) : Color.examGreen)
                    .padding(.vertical, 14)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(cs == .dark ? .white.opacity(0.5) : Color.examGreen.opacity(0.7))
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.examCard(cs))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(Color.examGreen.opacity(cs == .dark ? 0.55 : 0.75), lineWidth: 1.5))
        }
    }

    // MARK: - Result Sheet (채점 결과)  ────────────────────────────────────

    private var resultSheet: some View {
        let total  = totalQuestionsCount
        let wrong  = total - score
        let pct    = total > 0 ? Int(Double(score) / Double(total) * 100) : 0

        return ZStack {
            Color.examPaper(cs).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 6) {
                    Text("JLPT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.examGreen).kerning(2)
                    Text("채 점 결 과")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(cs == .dark ? .white : .black)
                        .kerning(5)
                }
                .padding(.bottom, 28)

                VStack(spacing: 3) {
                    Rectangle().fill(Color.examGreen).frame(height: 2)
                    Rectangle().fill(Color.examGreen.opacity(0.25)).frame(height: 1)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 18) {
                    resultRow(label: "정  답", value: "\(score)",   color: Color(red: 0.15, green: 0.55, blue: 0.20))
                    Divider()
                    resultRow(label: "오  답", value: "\(wrong)",   color: Color(red: 0.65, green: 0.10, blue: 0.12))
                    Divider()
                    resultRow(label: "정답률", value: "\(pct)％",   color: Color.examGreen)
                }
                .padding(.vertical, 28).padding(.horizontal, 36)

                VStack(spacing: 3) {
                    Rectangle().fill(Color.examGreen.opacity(0.25)).frame(height: 1)
                    Rectangle().fill(Color.examGreen).frame(height: 2)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Button {
                        if let set = selectedSet {
                            DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group1_set\(set)")
                            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: 0)
                        }
                        currentGroupIndex = 0
                        groupAnswers = [:]; groupShowExplanation = []
                        selectedAnswer = nil; showAnswer = false; showExplanation = false
                        progress = 0; score = 0
                        selectedSet = nil; questions = []; questionGroups = []
                        showResultSheet = false
                        dismiss()
                    } label: {
                        Text("완료")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.examGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
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
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(cs == .dark ? .white.opacity(0.60) : .black.opacity(0.55))
                .kerning(2)
            Spacer()
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    // MARK: - Logic  ────────────────────────────────────────────

    private func explanationEntitled(for questionIndex: Int) -> Bool {
        if storeManager.isPremium { return true }
        if let set = selectedSet, set == 1, questionIndex <= 4 { return true }
        return false
    }

    private var isExplanationEntitled: Bool {
        if storeManager.isPremium { return true }
        let firstIdx = currentGroup?.questionIndices.first ?? currentGroupIndex
        return explanationEntitled(for: firstIdx)
    }

    private func selectAnswerInGroup(question: Question, questionIndex: Int, answer: String) {
        guard groupAnswers[question.id] == nil else { return }
        groupAnswers[question.id] = answer
        
        if answer == question.answer {
            score += 1
            // 🌟 정답을 맞힌 경우 기존 오답 노트에서 제거
            removeIncorrectNoteIfNeeded(questionIndex: questionIndex)
        } else {
            // 🌟 틀린 경우 오답 노트에 자동 저장
            saveIncorrectNoteIfEligible(questionIndex: questionIndex)
        }
    }

    // MARK: - 오답 노트 연동

    private func saveIncorrectNoteIfEligible(questionIndex: Int) {
        guard let set = selectedSet, explanationEntitled(for: questionIndex) else { return }
        DatabaseManager.shared.saveIncorrectAnswer(level: level, quizGroup: "Group1_set\(set)", questionIndex: questionIndex)
    }

    private func removeIncorrectNoteIfNeeded(questionIndex: Int) {
        guard let set = selectedSet else { return }
        DatabaseManager.shared.deleteIncorrectAnswer(level: level, quizGroup: "Group1_set\(set)", questionIndex: questionIndex)
    }

    private func moveToNextGroup() {
        if !storeManager.isPremium, selectedSet == 1 {
            if currentGroupIndex >= 2 {
                showPurchaseView = true
                return
            }
        }
        
        if currentGroupIndex < questionGroups.count - 1 {
            currentGroupIndex += 1; groupAnswers = [:]; groupShowExplanation = []
            refreshSetProgress()
        } else {
            showResultSheet = true
        }
    }

    private func loadQuestionsForSet(_ set: Int) {
        questions      = DataLoader.load(set: set)
        questionGroups = DataLoader.groupQuestions(questions)
        let saved = DatabaseManager.shared.loadProgress(level: level, quizGroup: "Group1_set\(set)")
        currentGroupIndex    = saved < questionGroups.count ? saved : 0
        progress             = Double(currentGroupIndex) / Double(max(questionGroups.count, 1))
        groupAnswers = [:]; groupShowExplanation = []
        selectedAnswer = nil; showAnswer = false; showExplanation = false
    }

    // MARK: - refreshSetProgress() (set1 ~ set3)
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
    }

    private func resetToFirstQuestion() {
        currentGroupIndex = 0; progress = 0; score = 0
        groupAnswers = [:]; groupShowExplanation = []; selectedAnswer = nil
        showAnswer = false; showExplanation = false
        DatabaseManager.shared.resetProgress(level: level, quizGroup: quizGroup)
        if let set = selectedSet {
            DatabaseManager.shared.saveProgress(level: level, quizGroup: "Group1_set\(set)", index: 0)
        }
    }

    private func resetAndDismiss() {
        if let set = selectedSet { DatabaseManager.shared.resetProgress(level: level, quizGroup: "Group1_set\(set)") }
        currentGroupIndex = 0; groupAnswers = [:]
        groupShowExplanation = []; selectedAnswer = nil; showAnswer = false
        showExplanation = false; progress = 0; score = 0; selectedSet = nil
        questions = []; questionGroups = []
        isTabBarHidden = false; dismiss()
    }
}
