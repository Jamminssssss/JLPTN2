// GrammarPracticeView.swift
import SwiftUI
import NaturalLanguage

// MARK: - Puzzle Piece Model

struct PuzzlePiece: Identifiable, Equatable {
    let id: UUID
    let text: String
}

// MARK: - Puzzle State

enum PuzzleState {
    case playing, correct, wrong
}

// MARK: - Japanese Tokenizer

enum JapaneseTokenizer {

    private static let mergeSet: Set<Character> = [
        "は","が","を","に","で","と","も","の","へ","야","か","ね","よ","な","ぞ",
        "ぜ","さ","わ","し","て","ば","ら","り","も",
        "ハ","ガ","ヲ","ニ","デ","ト","モ","ノ","ヘ","ヤ","カ","ネ","ヨ","ナ",
        "ゾ","ゼ","サ","ワ","シ","テ","バ","ラ","リ",
        "ァ","ィ","ゥ","ェ","ォ","ッ","ャ","ュ","ョ","ヮ","ヵ","ヶ",
        "ぁ","ぃ","ぅ","ぇ","ぉ","っ","ゃ","ゅ","ょ","ゎ",
        "、","。","！","？","…","・","〜","〝","〞","ー","～"
    ]

    static func tokenize(_ sentence: String) -> [String] {

        var core         = sentence
        var sourceSuffix: String? = nil

        if let openIdx  = sentence.lastIndex(of: "（"),
           let closeIdx = sentence.lastIndex(of: "）"),
           openIdx < closeIdx {
            sourceSuffix = String(sentence[openIdx...closeIdx])
            core = String(sentence[..<openIdx]).trimmingCharacters(in: .whitespaces)
        }

        var tokens: [String] = []
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.setLanguage(.japanese)
        tokenizer.string = core
        tokenizer.enumerateTokens(in: core.startIndex..<core.endIndex) { range, _ in
            tokens.append(String(core[range]))
            return true
        }

        if tokens.isEmpty {
            tokens = core.map { String($0) }
        }

        var merged: [String] = []
        for token in tokens {
            if token.count == 1,
               let ch = token.first,
               mergeSet.contains(ch),
               !merged.isEmpty {
                merged[merged.count - 1] += token
            } else {
                merged.append(token)
            }
        }

        if let suffix = sourceSuffix {
            merged.append(suffix)
        }

        if merged.count < 2, let only = merged.first {
            let mid = only.index(only.startIndex, offsetBy: only.count / 2)
            merged = [String(only[..<mid]), String(only[mid...])]
        }

        return merged.filter { !$0.isEmpty }
    }
}

// MARK: - GrammarPracticeView

struct GrammarPracticeView: View {

    @StateObject private var grammarController = GrammarController()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var availablePieces:  [PuzzlePiece] = []
    @State private var placedPieces:     [PuzzlePiece] = []
    @State private var puzzleState:      PuzzleState   = .playing
    @State private var showHint:         Bool          = false
    @State private var wrongOffset:      CGFloat       = 0
    @State private var correctTokens:    [String]      = []

    @State private var fontScale:        Double        = 1.0

    @StateObject private var storeManager   = StoreKitManager.shared
    @State private var showPurchaseView:     Bool          = false
    private static let freeQuestionLimit    = 3

    @StateObject private var interstitialViewModel = InterstitialViewModel()
    @ObservedObject private var appAdManager = AppAdManager.shared
    
    @State private var adTimer: Timer?

    // MARK: Derived

    private var currentExample: GrammarExample {
        grammarController.examples[grammarController.currentExampleIndex]
    }

    private var currentLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private func localizedMeaning() -> String? {
        guard currentLanguageCode != "ja" else { return nil }
        switch currentLanguageCode {
        case "ko":                     return currentExample.meanings["ko"]
        case "zh","zh-Hans","zh-Hant": return currentExample.meanings["zh-Hans"]
        default:                       return currentExample.meanings[currentLanguageCode] ?? currentExample.meanings["en"]
        }
    }

    private func localizedTranslation() -> String? {
        guard currentLanguageCode != "ja" else { return nil }
        switch currentLanguageCode {
        case "ko":                     return currentExample.translations["ko"]
        case "zh","zh-Hans","zh-Hant": return currentExample.translations["zh-Hans"] ?? currentExample.translations["en"]
        default:                       return currentExample.translations[currentLanguageCode] ?? currentExample.translations["en"]
        }
    }

    // MARK: Puzzle Logic

    private func setupPuzzle() {
        let tokens    = JapaneseTokenizer.tokenize(currentExample.example)
        correctTokens = tokens

        var pieces = tokens.map { PuzzlePiece(id: UUID(), text: $0) }.shuffled()
        if pieces.map(\.text) == tokens, pieces.count > 1 { pieces.shuffle() }

        availablePieces = pieces
        placedPieces    = []
        puzzleState     = .playing
        showHint        = false
        wrongOffset     = 0
    }

    private func place(_ piece: PuzzlePiece) {
        guard puzzleState == .playing,
              let idx = availablePieces.firstIndex(of: piece) else { return }
        availablePieces.remove(at: idx)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
            placedPieces.append(piece)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if availablePieces.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { checkAnswer() }
        }
    }

    private func remove(_ piece: PuzzlePiece) {
        guard puzzleState == .playing,
              let idx = placedPieces.firstIndex(of: piece) else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
            placedPieces.remove(at: idx)
            availablePieces.append(piece)
        }
    }

    private func checkAnswer() {
        if placedPieces.map(\.text) == correctTokens {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { puzzleState = .correct }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { advance() }
        } else {
            puzzleState = .wrong
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.spring(response: 0.07, dampingFraction: 0.12)) { wrongOffset = 10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { wrongOffset = 0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        availablePieces.append(contentsOf: placedPieces)
                        placedPieces.removeAll()
                        puzzleState = .playing
                    }
                }
            }
        }
    }

    private func advance() {
        let nextIndex = grammarController.currentExampleIndex + 1

        if nextIndex >= GrammarPracticeView.freeQuestionLimit && !storeManager.isSubscribed {
            showPurchaseView = true
            return
        }

        if grammarController.currentExampleIndex < grammarController.examples.count - 1 {
            grammarController.nextExample(totalExamples: grammarController.examples.count)
            setupPuzzle()
        } else {
            grammarController.showCompletionScreen = true
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            AdaptiveTopBannerView()

            if grammarController.showCompletionScreen {
                completionView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor.ignoresSafeArea())
            } else {
                GeometryReader { geo in
                    let w  = geo.size.width
                    let h  = geo.size.height
                    let hp = w * 0.045
                    let answerH: CGFloat = max(90, h * 0.16)

                    VStack(spacing: 0) {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {

                                progressBar
                                    .padding(.horizontal, hp)
                                    .padding(.top, 14)
                                    .padding(.bottom, 12)

                                grammarCard
                                    .padding(.horizontal, hp)

                                sectionLabel("내 답안", systemImage: "message")
                                    .padding(.horizontal, hp)
                                    .padding(.top, 14)
                                    .padding(.bottom, 5)

                                answerArea
                                    .padding(.horizontal, hp)
                                    .frame(height: answerH)
                                    .offset(x: wrongOffset)

                                sectionLabel("단어 선택", systemImage: "hand.tap")
                                    .padding(.horizontal, hp)
                                    .padding(.top, 14)
                                    .padding(.bottom, 5)

                                tileBankView
                                    .padding(.horizontal, hp)

                                Spacer(minLength: 80)
                            }
                        }

                        navigationBar
                            .frame(height: 68)
                            .padding(.horizontal, hp)
                            .background(
                                (colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.96))
                                    .shadow(color: .black.opacity(0.09), radius: 8, x: 0, y: -2)
                            )
                    }
                    .frame(width: w, height: h)
                }
                .background(backgroundColor.ignoresSafeArea())
            }

            AdaptiveBottomBannerView()
        }
        .ignoresSafeArea(.container, edges: [.leading, .trailing])
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { menuButton }
        }
        .fullScreenCover(isPresented: $showPurchaseView) {
            PurchaseView()
        }
        .onAppear {
            grammarController.loadProgress()
            setupPuzzle()
            
            if !appAdManager.hasShownGrammarAd {
                adTimer?.invalidate()
                adTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                    Task { @MainActor in
                        await interstitialViewModel.loadAd()
                        if interstitialViewModel.isAdReady {
                            interstitialViewModel.showAd()
                            appAdManager.hasShownGrammarAd = true
                        }
                    }
                }
            }
        }
        // 🌟 복원 후 즉시 갱신
        .onReceive(NotificationCenter.default.publisher(for: .jlptCloudRestoreCompleted)) { _ in
            grammarController.loadProgress()
            setupPuzzle()
        }
        .onDisappear {
            adTimer?.invalidate()
        }
    }

    // MARK: Menu

    private var menuButton: some View {
        Menu {
            Button(action: {
                grammarController.resetProgress()
                ProgressManager.shared.clearGrammarProgress()
                grammarController.currentExampleIndex = 0
                grammarController.showCompletionScreen = false
                grammarController.showExample = false
                setupPuzzle()
            }) { Label("Restart", systemImage: "arrow.counterclockwise") }

            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Label("Return to Main Screen", systemImage: "house.fill")
            }

            Menu("Font Size") {
                Button("Small")  { fontScale = 0.8 }
                Button("Medium") { fontScale = 1.0 }
                Button("Large")  { fontScale = 1.2 }
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
        }
    }

    // MARK: Progress Bar

    private var progressBar: some View {
        let total   = max(1, grammarController.examples.count)
        let current = grammarController.currentExampleIndex
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.2)).frame(height: 5)
                Capsule()
                    .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(current) / CGFloat(total), height: 5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: current)
            }
        }
        .frame(height: 5)
    }

    // MARK: Grammar Card

    private var grammarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(currentExample.grammar)
                    .font(.system(size: 22 * fontScale, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)

                if let meaning = localizedMeaning() {
                    Text(meaning)
                        .font(.system(size: 15 * fontScale))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }

                Spacer()

                if localizedTranslation() != nil {
                    Button(action: { withAnimation(.easeInOut(duration: 0.18)) { showHint.toggle() } }) {
                        HStack(spacing: 5) {
                            Image(systemName: showHint ? "lightbulb.fill" : "lightbulb")
                                .font(.system(size: 14))
                            Text("ヒント")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(showHint ? .orange : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(showHint ? Color.orange.opacity(0.12) : Color.blue.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(showHint ? Color.orange.opacity(0.3) : Color.blue.opacity(0.25), lineWidth: 1.2)
                                )
                        )
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 13)).foregroundColor(.blue.opacity(0.7))
                Text("単語を正しい順番に並べてください")
                    .font(.system(size: 13 * fontScale)).foregroundColor(.secondary)
            }

            if showHint, let translation = localizedTranslation() {
                HStack(spacing: 8) {
                    Rectangle().fill(Color.orange).frame(width: 3).clipShape(Capsule())
                    Text(translation)
                        .font(.system(size: 14 * fontScale))
                        .foregroundColor(.orange).italic()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.07), radius: 8, x: 0, y: 2)
    }

    // MARK: Answer Area

    private var answerArea: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14)
                .stroke(answerBorderColor, lineWidth: puzzleState == .playing ? 1.5 : 2.5)
                .background(RoundedRectangle(cornerRadius: 14).fill(answerFillColor))
                .animation(.spring(response: 0.25), value: puzzleState)

            if placedPieces.isEmpty {
                Text("ここに単語を置いてください")
                    .font(.system(size: 16 * fontScale))
                    .foregroundColor(.gray.opacity(0.38))
                    .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    FlowLayout(spacing: 6) {
                        ForEach(placedPieces) { piece in
                            AnswerTile(text: piece.text, state: puzzleState, fontSize: 17 * fontScale) { remove(piece) }
                        }
                    }
                    .padding(.horizontal, 12).padding(.top, 12)

                    if puzzleState == .correct {
                        feedbackLabel(icon: "checkmark.circle.fill", text: "正解！🎉", color: .green)
                    } else if puzzleState == .wrong {
                        feedbackLabel(icon: "xmark.circle.fill", text: "もう一度試してください", color: .red)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var answerBorderColor: Color {
        switch puzzleState {
        case .playing: return Color.blue.opacity(0.35)
        case .correct: return .green
        case .wrong:   return .red
        }
    }

    private var answerFillColor: Color {
        switch puzzleState {
        case .playing: return colorScheme == .dark ? Color(white: 0.18) : Color.blue.opacity(0.03)
        case .correct: return Color.green.opacity(0.08)
        case .wrong:   return Color.red.opacity(0.08)
        }
    }

    // MARK: Tile Bank

    private var tileBankView: some View {
        Group {
            if availablePieces.isEmpty {
                HStack {
                    Spacer()
                    Label("全ての単語を配置しました", systemImage: "checkmark.circle")
                        .font(.system(size: 14)).foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 70)
            } else {
                FlowLayout(spacing: 10) {
                    ForEach(availablePieces) { piece in
                        BankTile(text: piece.text, fontSize: 19 * fontScale) { place(piece) }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(colorScheme == .dark ? Color(white: 0.19) : Color(white: 0.97))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: 0) {
            Button(action: {
                guard grammarController.currentExampleIndex > 0 else { return }
                grammarController.previousExample()
                setupPuzzle()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(grammarController.currentExampleIndex > 0 ? .blue : .gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(grammarController.currentExampleIndex > 0 ? Color.blue.opacity(0.12) : Color.clear))
            }
            .disabled(grammarController.currentExampleIndex == 0)

            Spacer()

            HStack(spacing: 5) {
                Text("\(grammarController.currentExampleIndex + 1)  /  \(grammarController.examples.count)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                if !storeManager.isSubscribed {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
            .background(Capsule().fill(Color.gray.opacity(0.13)))

            Spacer()

            let isNextLocked = (grammarController.currentExampleIndex + 1 >= GrammarPracticeView.freeQuestionLimit) && !storeManager.isSubscribed
            Button(action: { advance() }) {
                HStack(spacing: 4) {
                    if isNextLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                    } else {
                        Text("スキップ").font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundColor(isNextLocked ? .orange : .blue.opacity(0.75))
                .frame(height: 48).padding(.horizontal, 4)
            }
        }
    }

    // MARK: Completion View

    private var completionView: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle().fill(Color.yellow.opacity(0.15)).frame(width: 130, height: 130)
                Image(systemName: "star.fill").font(.system(size: 60)).foregroundColor(.yellow)
            }
            VStack(spacing: 10) {
                Text("全てのパズルクリア！").font(.system(size: 26, weight: .bold))
                Text("文法パズルを全て解きました。\nお疲れ様でした！🎉")
                    .font(.system(size: 15)).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).lineSpacing(4)
            }
            Button(action: {
                grammarController.resetProgress()
                ProgressManager.shared.clearGrammarProgress()
                grammarController.currentExampleIndex = 0
                grammarController.showCompletionScreen = false
                grammarController.showExample = false
                setupPuzzle()
            }) {
                Label("最初からやり直す", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    .frame(width: 230, height: 54).background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            Spacer()
        }
        .padding(32)
    }

    // MARK: Helpers

    private var cardBackground: Color { colorScheme == .dark ? Color(white: 0.2) : .white }
    private var backgroundColor: Color { colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.94) }

    @ViewBuilder
    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
    }

    @ViewBuilder
    private func feedbackLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text).fontWeight(.semibold)
        }
        .font(.system(size: 13)).foregroundColor(color)
        .padding(.horizontal, 14).padding(.bottom, 8)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: - BankTile

struct BankTile: View {
    let text:     String
    let fontSize: CGFloat
    let action:   () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.97))
                )
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.45), lineWidth: 1.5))
                .scaleEffect(pressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.15, dampingFraction: 0.7), value: pressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in pressed = false }
        )
    }
}

// MARK: - AnswerTile

struct AnswerTile: View {
    let text:     String
    let state:    PuzzleState
    let fontSize: CGFloat
    let action:   () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(fgColor)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(borderColor, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var fgColor: Color {
        switch state {
        case .playing: return colorScheme == .dark ? .white : Color(white: 0.15)
        case .correct: return .green
        case .wrong:   return .red
        }
    }
    private var bgColor: Color {
        switch state {
        case .playing: return colorScheme == .dark ? Color(white: 0.28) : Color(white: 0.91)
        case .correct: return Color.green.opacity(0.1)
        case .wrong:   return Color.red.opacity(0.1)
        }
    }
    private var borderColor: Color {
        switch state {
        case .playing: return Color.gray.opacity(0.3)
        case .correct: return Color.green.opacity(0.5)
        case .wrong:   return Color.red.opacity(0.5)
        }
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rH: CGFloat = 0, maxY: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > w, x > 0 { x = 0; y += rH + spacing; rH = 0 }
            x += sz.width + spacing; rH = max(rH, sz.height); maxY = max(maxY, y + rH)
        }
        return CGSize(width: w, height: maxY)
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, rH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > b.maxX, x > b.minX { x = b.minX; y += rH + spacing; rH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing; rH = max(rH, sz.height)
        }
    }
}

// MARK: - Array Extension

extension Array {
    func safeSlice(_ range: ClosedRange<Int>) -> ArraySlice<Element> {
        let lo = Swift.max(range.lowerBound, 0)
        let hi = Swift.min(range.upperBound, count - 1)
        guard lo <= hi else { return [] }
        return self[lo...hi]
    }
}
