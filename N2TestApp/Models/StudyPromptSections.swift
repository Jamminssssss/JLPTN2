import Foundation

/// Separates JLPT directions and questions from the text to read.
struct StudyPromptSections {
    let question: String?
    let passage: String?

    init(text: String?) {
        let text = Self.normalized(text)
        guard !text.isEmpty else {
            question = nil
            passage = nil
            return
        }

        // Older sets concatenate the directions and example without a newline.
        let firstSentenceEnd = text.firstIndex(where: { $0 == "。" || $0 == "\n" })
        let firstSentence = firstSentenceEnd.map { String(text[...$0]) } ?? text
        if ["選びなさい", "えらびなさい", "選んでください", "答えなさい"]
            .contains(where: { firstSentence.contains($0) }) {
            question = firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
            let remainder = firstSentenceEnd.map { Self.normalized(String(text[text.index(after: $0)...])) } ?? ""
            passage = remainder.isEmpty ? nil : remainder
        } else if ["か。", "か？", "か?", "どれ。", "どれ？", "どれ?"].contains(where: { text.hasSuffix($0) }) {
            question = text
            passage = nil
        } else {
            question = nil
            passage = text
        }
    }

    init(reading question: Question) {
        let primary = Self(text: question.question)
        let subText = Self.normalized(question.subQuestion)
        // Some image-based cloze groups use only a blank number here.
        let secondary = Self(text: Int(subText) == nil ? subText : nil)
        let questions = [primary.question, secondary.question]
            .compactMap { $0 }.reduce(into: [String]()) { result, text in
                if !result.contains(text) { result.append(text) }
            }.joined(separator: "\n\n")
        self.question = questions.isEmpty ? nil : questions
        let passages = [primary.passage, secondary.passage]
            .compactMap { $0 }.reduce(into: [String]()) { result, text in
                if !result.contains(text) { result.append(text) }
            }.joined(separator: "\n\n")
        passage = passages.isEmpty ? nil : passages
    }

    private static func normalized(_ text: String?) -> String {
        (text ?? "")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
