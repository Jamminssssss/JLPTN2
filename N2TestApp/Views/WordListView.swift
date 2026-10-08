import SwiftUI
import AVFoundation

struct WordListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var isSpeaking = false
    @StateObject private var interstitialViewModel = InterstitialViewModel()
    @State private var currentPage = 0
    @State private var visitedPages: Set<Int> = [0]
    @State private var isChangingPage = false
    private let pageSize = 20
    
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
    
    private var pageCount: Int { max(1, (filteredWords.count + pageSize - 1) / pageSize) }

    private var pageWords: [Word] {
        Array(filteredWords.dropFirst(currentPage * pageSize).prefix(pageSize))
    }

    private func nextPage(onChanged: @escaping () -> Void) {
        guard !isChangingPage, currentPage + 1 < pageCount else { return }
        isChangingPage = true
        synthesizer.stopSpeaking(at: .immediate)
        let advance = {
            currentPage += 1
            visitedPages.insert(currentPage)
            isChangingPage = false
            onChanged()
        }
        // After several pages of browsing, show one ad at an explicit page boundary.
        if visitedPages.count >= 3 {
            interstitialViewModel.showAtStudyBreak(onFinished: advance)
        } else {
            advance()
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    AdaptiveTopBannerView()
                    
                    ScrollViewReader { proxy in
                        VStack(spacing: 0) {
                            ScrollView {
                                LazyVStack(spacing: 20) {
                                    Color.clear.frame(height: 1).id("word-page-top")
                                    ForEach(pageWords, id: \.kanji) { word in
                                        WordRow(word: word)
                                            .onTapGesture { speakWord(word: word) }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 16)
                            }
                            if pageCount > 1 {
                                HStack {
                                    Button("이전 페이지") {
                                        synthesizer.stopSpeaking(at: .immediate)
                                        currentPage -= 1
                                        visitedPages.insert(currentPage)
                                        proxy.scrollTo("word-page-top", anchor: .top)
                                    }
                                    .disabled(currentPage == 0 || isChangingPage)
                                    Spacer()
                                    Text("\(currentPage + 1) / \(pageCount)")
                                        .monospacedDigit()
                                    Spacer()
                                    Button("다음 페이지") {
                                        nextPage { proxy.scrollTo("word-page-top", anchor: .top) }
                                    }
                                    .disabled(currentPage + 1 >= pageCount || isChangingPage)
                                }
                                .padding()
                            }
                        }
                    }

                    AdaptiveBottomBannerView()
                }
            }
            .navigationTitle("단어장")
            .navigationBarTitleDisplayMode(.inline)
        }
        .disabled(isChangingPage)
        .navigationViewStyle(StackNavigationViewStyle())
        .toolbar(.hidden, for: .tabBar)
        .task { await interstitialViewModel.loadAd() }
        .onDisappear {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
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
        guard LocalizedContent.currentLanguageCode != "ja" else { return nil }
        return LocalizedContent.value(in: word.meanings)
    }
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
