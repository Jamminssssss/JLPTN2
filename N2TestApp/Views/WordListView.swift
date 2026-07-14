import SwiftUI
import AVFoundation

struct WordListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var isSpeaking = false
    
    @StateObject private var interstitialViewModel = InterstitialViewModel()
    @State private var adTimer: Timer?
    
    @ObservedObject private var appAdManager = AppAdManager.shared
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
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
    
    
    var filteredWords: [Word] {
        return VocabDataLoader.shared.words
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    AdaptiveTopBannerView()
                    
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(filteredWords, id: \.kanji) { word in
                                WordRow(word: word)
                                    .onTapGesture {
                                        speakWord(word: word)
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, bannerHeight)
                    }
                    
                    AdaptiveBottomBannerView()
                }
            }
            .navigationTitle("단어장")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if !appAdManager.hasShownWordListAd {
                // ⭐️ 1. 화면에 진입하자마자 광고를 미리 로드해둡니다 (네트워크 대기 시간 최소화)
                Task { @MainActor in
                    if !interstitialViewModel.isAdReady {
                        await interstitialViewModel.loadAd()
                    }
                }
                
                // ⭐️ 2. 5초 대기 타이머 시작
                adTimer?.invalidate()
                adTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                    Task { @MainActor in
                        // 만약 5초가 지났는데도 네트워크 문제로 로드가 덜 되었다면 안전장치로 한번 더 로드 대기
                        if !interstitialViewModel.isAdReady {
                            await interstitialViewModel.loadAd()
                        }
                        
                        // 준비가 완료되었다면 광고 표시
                        if interstitialViewModel.isAdReady {
                            interstitialViewModel.showAd()
                            appAdManager.hasShownWordListAd = true
                        }
                    }
                }
            }
        }
        .onDisappear {
            // 화면을 벗어나면 타이머 해제
            adTimer?.invalidate()
        }
    }
    
    // 한국어 TTS 재생
    private func speakWord(word: Word) {
        let utterance = AVSpeechUtterance(string: word.meanings["ja"] ?? word.kanji)
        if let voice = AVSpeechSynthesisVoice(language: "ja-JP") {
            utterance.voice = voice
        }
        utterance.rate = 0.4
        utterance.pitchMultiplier = 1.2
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isSpeaking = false
        }
    }
}

struct WordRow: View {
    let word: Word
    
    var body: some View {
        VStack(spacing: 16) {
            // 단어만 표시 (한국어 기준)
            Text(word.kanji)
                .font(isIPad ? .largeTitle : .title)
                .fontWeight(.bold)
            
            // 의미 표시 (한국어는 생략, 나머지 언어는 기기 언어 기준)
            if let meaning = localizedMeaning(), !meaning.isEmpty {
                Text(meaning)
                    .font(isIPad ? .title2 : .body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
        }
        .frame(maxWidth: .infinity, minHeight: isIPad ? 200 : 150)
        .padding(.vertical, isIPad ? 32 : 24)
        .padding(.horizontal, isIPad ? 32 : 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
        )
    }
    
    private func localizedMeaning() -> String? {
        let languageCode: String = {
            if #available(iOS 16.0, *) {
                return Locale.current.language.languageCode?.identifier ?? "en"
            } else {
                return Locale.current.languageCode ?? "en"
            }
        }()
        
        switch languageCode {
        case "ja":
            return nil // 한국어는 의미 생략
        case "en":
            return word.meanings["en"]
        case "ko":
            return word.meanings["ko"]
        case "zh":
            return word.meanings["zh-Hans"] ?? word.meanings["zh-Hant"]
        default:
            return word.meanings["en"] // fallback
        }
    }
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
