// VocabDataLoader.swift
import Foundation

// ⚠️ Word / GrammarExample 이 이미 다른 파일에 정의되어 있다면 아래 두 struct는 제거하세요.
struct Word {
    let kanji: String
    let reading: String
    let meanings: [String: String]
}

struct GrammarExample {
    let grammar: String
    let example: String
    let meanings: [String: String]
    let translations: [String: String]
}

final class VocabDataLoader {

    static let shared = VocabDataLoader()
    private init() {}

    lazy var words: [Word] = parseWords()
    lazy var grammarExamples: [GrammarExample] = parseGrammar()

    // MARK: N2_vocab.csv (kanji, reading, meaning_ko/en/ja/zh)

    private func parseWords() -> [Word] {
        guard let url = Bundle.main.url(forResource: "N2_vocab", withExtension: "csv"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            print("[VocabDataLoader] ⚠️ N2_vocab.csv 로드 실패")
            return []
        }

        var result: [Word] = []
        for (i, row) in parseCSV(raw).enumerated() {
            if i == 0, row.first?.lowercased().trimmed == "kanji" { continue }
            guard row.count >= 6 else { continue }

            let kanji = row[0].trimmed
            let reading = row[1].trimmed
            guard !kanji.isEmpty, !reading.isEmpty else { continue }

            result.append(Word(
                kanji: kanji,
                reading: reading,
                meanings: [
                    "ko": row[2].trimmed,
                    "en": row[3].trimmed,
                    "ja": row[4].trimmed,
                    "zh-Hans": row[5].trimmed
                ]
            ))
        }
        return result
    }

    // MARK: N2_grammar.csv (grammar, example, meaning_ko/en/ja/zh, translation_ko/en/ja/zh)

    private func parseGrammar() -> [GrammarExample] {
        guard let url = Bundle.main.url(forResource: "N2_grammar", withExtension: "csv"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            print("[VocabDataLoader] ⚠️ N2_grammar.csv 로드 실패")
            return []
        }

        var result: [GrammarExample] = []
        for (i, row) in parseCSV(raw).enumerated() {
            if i == 0, row.first?.lowercased().trimmed == "grammar" { continue }
            guard row.count >= 10 else { continue }

            let grammar = row[0].trimmed
            let example = row[1].trimmed
            guard !grammar.isEmpty, !example.isEmpty else { continue }

            result.append(GrammarExample(
                grammar: grammar,
                example: example,
                meanings: [
                    "ko": row[2].trimmed,
                    "en": row[3].trimmed,
                    "ja": row[4].trimmed,
                    "zh-Hans": row[5].trimmed
                ],
                translations: [
                    "ko": row[6].trimmed,
                    "en": row[7].trimmed,
                    "ja": row[8].trimmed,
                    "zh-Hans": row[9].trimmed
                ]
            ))
        }
        return result
    }

    // MARK: RFC 4180 CSV Parser (멀티라인 필드 지원)

    private func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false

        let chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))
        var i = chars.startIndex

        while i < chars.endIndex {
            let ch = chars[i]
            if inQuotes {
                if ch == "\"" {
                    let next = chars.index(after: i)
                    if next < chars.endIndex, chars[next] == "\"" {
                        field.append("\"")
                        i = chars.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"": inQuotes = true
                case ",":
                    fields.append(field); field = ""
                case "\n":
                    fields.append(field); field = ""
                    if !fields.isEmpty { rows.append(fields); fields = [] }
                default:
                    field.append(ch)
                }
            }
            i = chars.index(after: i)
        }

        fields.append(field)
        if fields.contains(where: { !$0.isEmpty }) { rows.append(fields) }

        return rows
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
    }
}
