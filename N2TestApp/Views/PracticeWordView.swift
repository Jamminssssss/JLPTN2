// PracticeWordView.swift
import SwiftUI
import PencilKit
import AVFoundation

struct PracticeWordView: View {
    @StateObject private var wordController = WordController()
    @State private var canvasView = PKCanvasView()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.colorScheme) var colorScheme
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var isSpeaking = false
    @State private var fontScale: CGFloat = 1.0
    @State private var showPurchaseView = false
    @StateObject private var storeManager = StoreKitManager.shared

    @StateObject private var interstitialViewModel = InterstitialViewModel()
    @ObservedObject private var appAdManager = AppAdManager.shared
    @State private var adTimer: Timer?

    @State private var strokeAnimationDone = false
    @State private var penColor: Color = Color(UIColor.label)
    @State private var showColorPicker = false

    private var isWritingEntitled: Bool { storeManager.isSubscribed || wordController.currentWordIndex < 3 }

    private var currentLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }

    private func getLocalizedMeaning() -> String? {
        if currentLanguageCode == "ja" { return nil }
        switch currentLanguageCode {
        case "ko":                           return currentWord.meanings["ko"]
        case "zh", "zh-Hans", "zh-Hant":    return currentWord.meanings["zh-Hans"]
        case "vi":                           return currentWord.meanings["vi"]
        case "th":                           return currentWord.meanings["th"]
        case "fr":                           return currentWord.meanings["fr"]
        default:                             return currentWord.meanings["en"]
        }
    }

    var currentWord: Word {
        wordController.words[wordController.currentWordIndex]
    }

    private func speakText(_ text: String) {
        if isSpeaking { speechSynthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        isSpeaking = true
        speechSynthesizer.speak(utterance)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { isSpeaking = false }
    }

    private func resetForNewWord() {
        canvasView.drawing = PKDrawing()
        strokeAnimationDone = false
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if geometry.size.height > geometry.size.width {
                    AdaptiveTopBannerView()
                }

                ZStack {
                    (colorScheme == .dark ? Color.black : Color.white)
                        .ignoresSafeArea()

                    if wordController.showCompletionScreen {
                        completionCanvasSection(geometry: geometry)
                    } else if wordController.showGuide {
                        strokeGuideView(geometry: geometry)
                    } else {
                        writingPracticeSection(geometry: geometry)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if geometry.size.height > geometry.size.width {
                    AdaptiveBottomBannerView()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .onAppear {
            wordController.loadProgress()
            
            if !appAdManager.hasPracticeWordAd {
                adTimer?.invalidate()
                adTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                    Task { @MainActor in
                        await interstitialViewModel.loadAd()
                        if interstitialViewModel.isAdReady {
                            interstitialViewModel.showAd()
                            appAdManager.hasPracticeWordAd = true
                        }
                    }
                }
            }
        }
        // 🌟 복원 후 즉시 갱신
        .onReceive(NotificationCenter.default.publisher(for: .jlptCloudRestoreCompleted)) { _ in
            wordController.loadProgress()
            resetForNewWord()
        }
        .onDisappear {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
            adTimer?.invalidate()
        }
        .fullScreenCover(isPresented: $showPurchaseView) { PurchaseView() }
    }

    // MARK: - 가이드 화면

    @ViewBuilder
    private func strokeGuideView(geometry: GeometryProxy) -> some View {
        let isPortrait = geometry.size.height > geometry.size.width

        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer(minLength: 20)

                    Text(currentWord.kanji)
                        .font(.system(size: (horizontalSizeClass == .regular ? 160 : 120) * fontScale))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()

                    if let meaning = getLocalizedMeaning() {
                        Text(meaning)
                            .font(.system(size: (horizontalSizeClass == .regular ? 28 : 22) * fontScale))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 20)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            wordController.showGuide = false
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                            Text("じゃあ、書いてみて。")
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: isPortrait ? 17 : 15))
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(Color.white)
                        .cornerRadius(24)
                    }
                    .padding(.bottom, isPortrait ? 32 : 16)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .transition(.opacity)
        .zIndex(2)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                speakText(currentWord.kanji)
            }
        }
    }

    // MARK: - 쓰기 연습 화면

    @ViewBuilder
    private func writingPracticeSection(geometry: GeometryProxy) -> some View {
        let isPortrait = geometry.size.height > geometry.size.width
        let canvasSize: CGSize = isPortrait
            ? CGSize(width: geometry.size.width * 0.9,  height: geometry.size.height * 0.72)
            : CGSize(width: geometry.size.width * 0.95, height: geometry.size.height * 0.68)

        VStack(spacing: 0) {
            ZStack {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    CanvasView(canvasView: $canvasView,
                               colorScheme: colorScheme,
                               isDrawingEnabled: isWritingEntitled,
                               isEraser: wordController.isEraser,
                               penColor: penColor)
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .overlay(
                            BackgroundCharactersOverlay(
                                text: currentWord.kanji,
                                isPortrait: isPortrait,
                                canvasSize: canvasSize,
                                fontScale: fontScale
                            )
                            .allowsHitTesting(false)
                        )
                }

                if !isWritingEntitled {
                    lockOverlay(isPortrait: isPortrait)
                }
            }
            .padding(.top, isPortrait ? 16 : 8)

            bottomControlsBar(isPortrait: isPortrait, canvasSize: canvasSize)
        }
    }

    // MARK: - 완료 후 캔버스 화면

    @ViewBuilder
    private func completionCanvasSection(geometry: GeometryProxy) -> some View {
        let isPortrait = geometry.size.height > geometry.size.width
        let canvasSize: CGSize = isPortrait
            ? CGSize(width: geometry.size.width * 0.9,  height: geometry.size.height * 0.8)
            : CGSize(width: geometry.size.width * 0.95, height: geometry.size.height * 0.8)

        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                CanvasView(canvasView: $canvasView,
                           colorScheme: colorScheme,
                           isDrawingEnabled: isWritingEntitled,
                           isEraser: wordController.isEraser,
                           penColor: penColor)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .overlay(
                        BackgroundCharactersOverlay(
                            text: currentWord.kanji,
                            isPortrait: isPortrait,
                            canvasSize: canvasSize,
                            fontScale: fontScale
                        )
                        .allowsHitTesting(false)
                    )
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity)

            HStack(spacing: isPortrait ? 16 : 12) {
                if isWritingEntitled {
                    circleButton(icon: "arrow.left", isPortrait: isPortrait) {
                        wordController.previousWord()
                        resetForNewWord()
                    }
                    circleButton(icon: "eye", isPortrait: isPortrait) {
                        withAnimation(.easeInOut(duration: 0.3)) { wordController.showGuide = true }
                        DispatchQueue.main.async { speakText(currentWord.kanji) }
                        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                            withAnimation(.easeInOut(duration: 0.3)) { wordController.showGuide = false }
                        }
                    }
                    toolButton(icon: "pencil", isActive: !wordController.isEraser, isPortrait: isPortrait) {
                        wordController.isEraser = false
                    }
                    toolButton(icon: "eraser", isActive: wordController.isEraser, isPortrait: isPortrait) {
                        wordController.isEraser = true
                    }
                    colorPickerButton(isPortrait: isPortrait)
                    if wordController.currentWordIndex < wordController.words.count - 1 {
                        circleButton(icon: "arrow.right", isPortrait: isPortrait) {
                            if storeManager.isSubscribed || wordController.currentWordIndex < 2 {
                                wordController.nextWord(totalWords: wordController.words.count)
                                resetForNewWord()
                            } else {
                                showPurchaseView = true
                            }
                        }
                    }
                }
            }
            .padding(.vertical, isPortrait ? 16 : 8)
            .padding(.bottom, isPortrait ? 20 : 10)
        }
        .zIndex(1)
    }

    // MARK: - 하단 버튼바

    @ViewBuilder
    private func bottomControlsBar(isPortrait: Bool, canvasSize: CGSize) -> some View {
        HStack(spacing: isPortrait ? 16 : 12) {
            circleButton(icon: "arrow.left", isPortrait: isPortrait) {
                wordController.previousWord()
                resetForNewWord()
            }
            circleButton(icon: "eye", isPortrait: isPortrait) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    wordController.showGuide = true
                    strokeAnimationDone = false
                }
            }
            toolButton(icon: "pencil", isActive: !wordController.isEraser, isPortrait: isPortrait) {
                wordController.isEraser = false
            }
            toolButton(icon: "eraser", isActive: wordController.isEraser, isPortrait: isPortrait) {
                wordController.isEraser = true
            }

            colorPickerButton(isPortrait: isPortrait)

            if wordController.currentWordIndex < wordController.words.count - 1 {
                circleButton(icon: "arrow.right", isPortrait: isPortrait) {
                    if storeManager.isSubscribed || wordController.currentWordIndex < 2 {
                        wordController.nextWord(totalWords: wordController.words.count)
                        resetForNewWord()
                    } else {
                        showPurchaseView = true
                    }
                }
            }
        }
        .padding(.vertical, isPortrait ? 16 : 8)
        .padding(.bottom, isPortrait ? 20 : 10)
    }

    // MARK: - 잠금 오버레이

    @ViewBuilder
    private func lockOverlay(isPortrait: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.55).cornerRadius(10)
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: isPortrait ? 40 : 32))
                    .foregroundColor(.white)
                Text("구독하면 모든 단어를\n연습할 수 있어요")
                    .font(.system(size: isPortrait ? 16 : 13, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Button(action: { showPurchaseView = true }) {
                    Text("구독하기")
                        .font(.system(size: isPortrait ? 15 : 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(20)
                }
            }
        }
    }


    // MARK: - 공통 원형 버튼

    private func circleButton(icon: String, isPortrait: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isPortrait ? 20 : 16))
                .foregroundColor(.white)
                .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                .background(Color.blue)
                .clipShape(Circle())
        }
    }

    private func toolButton(icon: String, isActive: Bool, isPortrait: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: isPortrait ? 20 : 16))
                .foregroundColor(.white)
                .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                .background(isActive ? Color.blue : Color.gray.opacity(0.5))
                .clipShape(Circle())
                .overlay(Circle().stroke(isActive ? Color.white.opacity(0.4) : Color.clear, lineWidth: 2))
        }
    }

    private let paletteColors: [(Color, String)] = [
        (Color(UIColor.label),  "기본"),
        (.red,                  "빨강"),
        (.orange,               "주황"),
        (.yellow,               "노랑"),
        (.green,                "초록"),
        (.blue,                 "파랑"),
        (.purple,               "보라"),
        (.pink,                 "분홍"),
    ]

    private func colorPickerButton(isPortrait: Bool) -> some View {
        let size: CGFloat = isPortrait ? 44 : 36
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showColorPicker.toggle()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: size, height: size)
                Circle()
                    .fill(penColor)
                    .frame(width: size * 0.58, height: size * 0.58)
                    .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.5))
            }
        }
        .overlay(alignment: .top) {
            if showColorPicker {
                colorPalettePopup(buttonSize: size)
                    .offset(y: -(size + 12 + CGFloat(paletteColors.count / 4 + 1) * 52))
                    .zIndex(100)
            }
        }
    }

    private func colorPalettePopup(buttonSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            let columns = Array(repeating: GridItem(.fixed(44), spacing: 8), count: 4)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(paletteColors, id: \.1) { color, name in
                    Button(action: {
                        penColor = color
                        wordController.isEraser = false
                        withAnimation { showColorPicker = false }
                    }) {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(penColor == color ? Color.white : Color.white.opacity(0.25), lineWidth: penColor == color ? 2.5 : 1)
                                )
                            if penColor == color {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(color == .yellow ? .black : .white)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 12)
        .frame(width: 4 * 44 + 3 * 8 + 24)
    }

    // MARK: - 툴바

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Button(action: {
                    wordController.resetProgress()
                    ProgressManager.shared.clearWordProgress()
                    wordController.currentWordIndex = 0
                    wordController.showCompletionScreen = false
                    wordController.showGuide = false
                    canvasView.drawing = PKDrawing()
                }) {
                    Label("처음으로", systemImage: "arrow.counterclockwise")
                }
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Label("홈 화면으로 돌아가기", systemImage: "house.fill")
                }
                Menu("글자 크기") {
                    Button("작게") { fontScale = 0.8 }
                    Button("보통") { fontScale = 1.0 }
                    Button("크게") { fontScale = 1.2 }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - CanvasView

struct CanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var colorScheme: ColorScheme
    var isDrawingEnabled: Bool = true
    var isEraser: Bool = false
    var penColor: Color = Color(UIColor.label)

    class Coordinator: NSObject {
        var lastColorScheme: ColorScheme?
        var lastIsEraser: Bool?
        var lastIsEnabled: Bool?
        var lastPenColor: Color?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.isMultipleTouchEnabled = true
        canvasView.isUserInteractionEnabled = isDrawingEnabled
        canvasView.drawingGestureRecognizer.isEnabled = isDrawingEnabled
        canvasView.drawingGestureRecognizer.delaysTouchesBegan = false
        canvasView.drawingGestureRecognizer.delaysTouchesEnded = false
        canvasView.drawingGestureRecognizer.cancelsTouchesInView = false
        canvasView.drawingGestureRecognizer.require(toFail: canvasView.panGestureRecognizer)
        applyAppearance(to: canvasView)
        context.coordinator.lastColorScheme = colorScheme
        context.coordinator.lastIsEraser    = isEraser
        context.coordinator.lastIsEnabled   = isDrawingEnabled
        context.coordinator.lastPenColor    = penColor
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        let c = context.coordinator
        if c.lastIsEnabled != isDrawingEnabled {
            c.lastIsEnabled = isDrawingEnabled
            uiView.isUserInteractionEnabled = isDrawingEnabled
            uiView.drawingGestureRecognizer.isEnabled = isDrawingEnabled
        }
        let schemeChanged  = c.lastColorScheme != colorScheme
        let eraserChanged  = c.lastIsEraser    != isEraser
        let colorChanged   = c.lastPenColor    != penColor
        guard schemeChanged || eraserChanged || colorChanged else { return }
        c.lastColorScheme = colorScheme
        c.lastIsEraser    = isEraser
        c.lastPenColor    = penColor
        applyAppearance(to: uiView)
    }

    private func applyAppearance(to canvas: PKCanvasView) {
        canvas.isOpaque = true
        canvas.backgroundColor = (colorScheme == .dark)
            ? UIColor(white: 0.10, alpha: 1.0)
            : .white
        if isEraser {
            canvas.tool = PKEraserTool(.vector)
        } else {
            let uiColor = UIColor(penColor)
            canvas.tool = PKInkingTool(.pen, color: uiColor, width: 2.0)
        }
    }
}

// MARK: - BackgroundCharactersOverlay

struct BackgroundCharactersOverlay: View {
    let text: String
    let isPortrait: Bool
    let canvasSize: CGSize
    let fontScale: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private var guideColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.25) : Color.gray.opacity(0.2)
    }

    var body: some View {
        Group {
            if isPortrait {
                if text.count <= 2 {
                    HStack(spacing: 20) {
                        ForEach(Array(text), id: \.self) { char in
                            Text(String(char))
                                .font(.system(size: min(canvasSize.width, canvasSize.height) * 0.4 * fontScale))
                                .fontWeight(.bold)
                                .foregroundColor(guideColor)
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(text), id: \.self) { char in
                            Text(String(char))
                                .font(.system(size: min(canvasSize.width, canvasSize.height) * 0.3 * fontScale))
                                .fontWeight(.bold)
                                .foregroundColor(guideColor)
                        }
                    }
                }
            } else {
                HStack(spacing: 30) {
                    ForEach(Array(text), id: \.self) { char in
                        Text(String(char))
                            .font(.system(size: min(canvasSize.width, canvasSize.height) * 0.5 * fontScale))
                            .fontWeight(.bold)
                            .foregroundColor(guideColor)
                    }
                }
            }
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

// MARK: - Color Hex 확장

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
