import Foundation

class GrammarController: ObservableObject {
    @Published var currentExampleIndex = 0
    @Published var showExample = false
    @Published var isHighlighted = false
    @Published var showCompletionScreen = false
    
    func speakGrammar(_ grammar: String) {
        AudioManager.shared.speakJapanese(text: grammar)
    }
    
    func speakExample(_ example: String) {
        AudioManager.shared.speakJapanese(text: example)
    }
    
    func nextExample(totalExamples: Int) {
        if currentExampleIndex < totalExamples - 1 {
            currentExampleIndex += 1
            showExample = false
            ProgressManager.shared.saveGrammarProgress(grammarIndex: currentExampleIndex)
        } else {
            showCompletionScreen = true
            ProgressManager.shared.clearGrammarProgress()
        }
    }
    
    func previousExample() {
        if currentExampleIndex > 0 {
            currentExampleIndex -= 1
            showExample = false
            ProgressManager.shared.saveGrammarProgress(grammarIndex: currentExampleIndex)
        }
    }
    
    func loadProgress() {
        if let lastProgress = ProgressManager.shared.getLastGrammarProgress() {
            currentExampleIndex = lastProgress
        }
    }
    
    func resetProgress() {
        currentExampleIndex = 0
        showExample = false
        showCompletionScreen = false
        ProgressManager.shared.clearGrammarProgress()
    }
}
