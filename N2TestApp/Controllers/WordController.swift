import Foundation

class WordController: ObservableObject {
    @Published var currentWordIndex = 0
    @Published var showGuide = true
    @Published var isEraser = false
    @Published var showCompletionScreen = false

    let words: [Word] = VocabDataLoader.shared.words

    func speakWord(_ word: Word) {
        AudioManager.shared.speakJapanese(text: word.reading)
    }

    func toggleTool() { isEraser.toggle() }

    func nextWord(totalWords: Int) {
        if currentWordIndex < totalWords - 1 {
            currentWordIndex += 1
            showGuide = true
            ProgressManager.shared.saveWordProgress(wordIndex: currentWordIndex)
        } else {
            showCompletionScreen = true // 🌟 clearWordProgress() 삭제됨
        }
    }

    func previousWord() {
        if currentWordIndex > 0 {
            currentWordIndex -= 1
            showGuide = true
            ProgressManager.shared.saveWordProgress(wordIndex: currentWordIndex)
        }
    }

    func resetProgress() {
        currentWordIndex = 0
        showGuide = true
        showCompletionScreen = false
        ProgressManager.shared.clearWordProgress()
    }

    func loadProgress() {
        if let lastProgress = ProgressManager.shared.getLastWordProgress() {
            currentWordIndex = lastProgress
        }
    }
}
