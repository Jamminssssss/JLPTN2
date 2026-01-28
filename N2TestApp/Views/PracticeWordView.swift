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
    
    private var isWritingEntitled: Bool { storeManager.isSubscribed || wordController.currentWordIndex == 0 }
    
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
            return currentWord.meanings["ko"]
        case "zh", "zh-Hans", "zh-Hant":
            return currentWord.meanings["zh-Hans"]
        default:
            // 그 외 언어는 영어로 기본 표시
            return currentWord.meanings["en"]
        }
    }
    
    var currentWord: Word {
        words[wordController.currentWordIndex]
    }
    
    private func speakText(_ text: String) {
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        isSpeaking = true
        speechSynthesizer.speak(utterance)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSpeaking = false
        }
    }
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                AdaptiveTopBannerView()
                
                ZStack {
                    (colorScheme == .dark ? Color.black : Color.white)
                        .ignoresSafeArea()
                    
                    if wordController.showCompletionScreen {
                        VStack(spacing: 0) {
                            let isPortrait = geometry.size.height > geometry.size.width
                            let canvasSize: CGSize = isPortrait
                                ? CGSize(width: geometry.size.width * 0.9, height: geometry.size.height * 0.8)
                                : CGSize(width: geometry.size.width * 0.95, height: geometry.size.height * 0.8)
                            
                            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                                VStack(spacing: 10) {
                                    CanvasView(canvasView: $canvasView, colorScheme: colorScheme, isDrawingEnabled: isWritingEntitled)
                                        .frame(width: canvasSize.width, height: canvasSize.height)
                                        .background(colorScheme == .dark ? Color.black : Color.white)
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
                            }
                            .padding(.horizontal)
                            .frame(maxHeight: .infinity)
                            
                            HStack(spacing: isPortrait ? 16 : 12) {
                                if isWritingEntitled {
                                    Button(action: {
                                        wordController.previousWord()
                                        canvasView.drawing = PKDrawing()
                                    }) {
                                        Image(systemName: "arrow.left")
                                            .font(.system(size: isPortrait ? 20 : 16))
                                            .foregroundColor(.white)
                                            .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            wordController.showGuide = true
                                        }
                                        DispatchQueue.main.async {
                                            speakText(currentWord.kanji)
                                        }
                                        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                wordController.showGuide = false
                                            }
                                        }
                                    }) {
                                        Image(systemName: "eye")
                                            .font(.system(size: isPortrait ? 20 : 16))
                                            .foregroundColor(.white)
                                            .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: {
                                        wordController.toggleTool()
                                        if wordController.isEraser {
                                            canvasView.tool = PKEraserTool(.vector)
                                        } else {
                                            canvasView.tool = PKInkingTool(.pen, color: .black, width: 2.0)
                                        }
                                    }) {
                                        Image(systemName: wordController.isEraser ? "pencil" : "eraser")
                                            .font(.system(size: isPortrait ? 20 : 16))
                                            .foregroundColor(.white)
                                            .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: {
                                        if storeManager.isSubscribed {
                                            if wordController.currentWordIndex < words.count - 1 {
                                                wordController.nextWord(totalWords: words.count)
                                                canvasView.drawing = PKDrawing()
                                            }
                                        } else {
                                            showPurchaseView = true
                                        }
                                    }) {
                                        if wordController.currentWordIndex < words.count - 1 {
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: isPortrait ? 20 : 16))
                                                .foregroundColor(.white)
                                                .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                                                .background(Color.blue)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, isPortrait ? 16 : 8)
                            .padding(.bottom, isPortrait ? 20 : 10)
                        }
                    } else if wordController.showGuide {
                        Color.black
                            .ignoresSafeArea()
                            .overlay(
                                VStack(spacing: 20) {
                                    Text(currentWord.kanji)
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
                            .zIndex(2)
                            .onAppear {
                                Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        wordController.showGuide = false
                                    }
                                }
                            }
                    } else {
                        VStack(spacing: 0) {
                            let isPortrait = geometry.size.height > geometry.size.width
                            let canvasSize: CGSize = isPortrait
                                ? CGSize(width: geometry.size.width * 0.9, height: geometry.size.height * 0.8)
                                : CGSize(width: geometry.size.width * 0.95, height: geometry.size.height * 0.8)
                            
                            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                                VStack(spacing: 10) {
                                    CanvasView(canvasView: $canvasView, colorScheme: colorScheme, isDrawingEnabled: isWritingEntitled)
                                        .frame(width: canvasSize.width, height: canvasSize.height)
                                        .background(colorScheme == .dark ? Color.black : Color.white)
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
                            }
                            .padding(.horizontal)
                            .frame(maxHeight: .infinity)
                            
                            HStack(spacing: isPortrait ? 16 : 12) {
                                if isWritingEntitled {
                                    Button(action: {
                                        wordController.previousWord()
                                        canvasView.drawing = PKDrawing()
                                    }) {
                                        Image(systemName: "arrow.left")
                                            .font(.system(size: isPortrait ? 20 : 16))
                                            .foregroundColor(.white)
                                            .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            wordController.showGuide = true
                                        }
                                        DispatchQueue.main.async {
                                            speakText(currentWord.kanji)
                                        }
                                        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                wordController.showGuide = false
                                            }
                                        }
                                    }) {
                                        Image(systemName: "eye")
                                            .font(.system(size: isPortrait ? 20 : 16))
                                            .foregroundColor(.white)
                                            .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: {
                                        wordController.toggleTool()
                                        if wordController.isEraser {
                                            canvasView.tool = PKEraserTool(.vector)
                                        } else {
                                            canvasView.tool = PKInkingTool(.pen, color: .black, width: 2.0)
                                        }
                                    }) {
                                        Image(systemName: wordController.isEraser ? "pencil" : "eraser")
                                            .font(.system(size: isPortrait ? 20 : 16))
                                            .foregroundColor(.white)
                                            .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                                            .background(Color.blue)
                                            .clipShape(Circle())
                                    }
                                    
                                    Button(action: {
                                        if storeManager.isSubscribed {
                                            if wordController.currentWordIndex < words.count - 1 {
                                                wordController.nextWord(totalWords: words.count)
                                                canvasView.drawing = PKDrawing()
                                            }
                                        } else {
                                            showPurchaseView = true
                                        }
                                    }) {
                                        if wordController.currentWordIndex < words.count - 1 {
                                            Image(systemName: "arrow.right")
                                                .font(.system(size: isPortrait ? 20 : 16))
                                                .foregroundColor(.white)
                                                .frame(width: isPortrait ? 44 : 36, height: isPortrait ? 44 : 36)
                                                .background(Color.blue)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, isPortrait ? 16 : 8)
                            .padding(.bottom, isPortrait ? 20 : 10)
                        }
                        .zIndex(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                AdaptiveBottomBannerView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
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
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Label("홈 화면으로 돌아가기", systemImage: "house.fill")
                    }
                    Menu("글자 크기") {
                        Button(action: {
                            fontScale = 0.8
                        }) {
                            Text("작게")
                        }
                        Button(action: {
                            fontScale = 1.0
                        }) {
                            Text("보통")
                        }
                        Button(action: {
                            fontScale = 1.2
                        }) {
                            Text("크게")
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
            wordController.loadProgress()
        }
        .onDisappear {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
        .sheet(isPresented: $showPurchaseView) {
            PurchaseView()
        }
    }
}

struct CanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    var colorScheme: ColorScheme
    var isDrawingEnabled: Bool = true
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        canvasView.isMultipleTouchEnabled = true
        canvasView.isUserInteractionEnabled = isDrawingEnabled
        canvasView.drawingGestureRecognizer.isEnabled = isDrawingEnabled
        canvasView.drawingGestureRecognizer.delaysTouchesBegan = false
        canvasView.drawingGestureRecognizer.delaysTouchesEnded = false
        canvasView.drawingGestureRecognizer.cancelsTouchesInView = false
        canvasView.drawingGestureRecognizer.require(toFail: canvasView.panGestureRecognizer)
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        let penColor: UIColor = (colorScheme == .dark) ? .white : .black
        let ink = PKInkingTool(.pen, color: penColor, width: 2.0)
        uiView.tool = ink
        uiView.isUserInteractionEnabled = isDrawingEnabled
        uiView.drawingGestureRecognizer.isEnabled = isDrawingEnabled
    }
}

struct BackgroundCharactersOverlay: View {
    let text: String
    let isPortrait: Bool
    let canvasSize: CGSize
    let fontScale: CGFloat
    
    var body: some View {
        Group {
            if isPortrait {
                if text.count <= 2 {
                    HStack(spacing: 20) {
                        ForEach(Array(text), id: \.self) { char in
                            Text(String(char))
                                .font(.system(size: min(canvasSize.width, canvasSize.height) * 0.4 * fontScale))
                                .fontWeight(.bold)
                                .foregroundColor(.gray.opacity(0.2))
                        }
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(text), id: \.self) { char in
                            Text(String(char))
                                .font(.system(size: min(canvasSize.width, canvasSize.height) * 0.3 * fontScale))
                                .fontWeight(.bold)
                                .foregroundColor(.gray.opacity(0.2))
                        }
                    }
                }
            } else {
                HStack(spacing: 30) {
                    ForEach(Array(text), id: \.self) { char in
                        Text(String(char))
                            .font(.system(size: min(canvasSize.width, canvasSize.height) * 0.5 * fontScale))
                            .fontWeight(.bold)
                            .foregroundColor(.gray.opacity(0.2))
                    }
                }
            }
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}
