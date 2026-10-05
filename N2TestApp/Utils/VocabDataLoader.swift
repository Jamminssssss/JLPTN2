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

/// 앱에서 선택된 언어를 CSV 콘텐츠 언어 키로 정규화한다.
/// `languageCode`만 사용하면 중국어의 Hans/Hant 구분이 사라지므로 전체 식별자를 사용한다.
enum LocalizedContent {
    private static let supportedLanguageCodes = Set([
        "ko", "en", "ja", "zh-Hans", "zh-Hant", "fr", "id", "es", "th", "vi"
    ])

    static var currentLanguageCode: String {
        let candidates = Bundle.main.preferredLocalizations
            + Locale.preferredLanguages
            + [Locale.current.identifier]

        for identifier in candidates {
            let code = normalizedLanguageCode(identifier)
            if supportedLanguageCodes.contains(code) { return code }
        }
        return "en"
    }

    static func value(in values: [String: String]) -> String? {
        let code = currentLanguageCode
        let preferredKeys: [String]

        switch code {
        case "zh-Hant": preferredKeys = ["zh-Hant", "zh-Hans", "en", "ko"]
        case "zh-Hans": preferredKeys = ["zh-Hans", "zh-Hant", "en", "ko"]
        default:         preferredKeys = [code, "en", "ko"]
        }

        return preferredKeys.lazy
            .compactMap { values[$0]?.trimmed }
            .first { !$0.isEmpty }
    }

    private static func normalizedLanguageCode(_ identifier: String) -> String {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if normalized.hasPrefix("zh") {
            let usesTraditionalChinese = ["hant", "-tw", "-hk", "-mo"]
                .contains { normalized.contains($0) }
            return usesTraditionalChinese ? "zh-Hant" : "zh-Hans"
        }

        switch normalized.split(separator: "-").first.map(String.init) {
        case "ko": return "ko"
        case "en": return "en"
        case "ja": return "ja"
        case "fr": return "fr"
        case "id": return "id"
        case "es": return "es"
        case "th": return "th"
        case "vi": return "vi"
        default:   return normalized
        }
    }
}

final class VocabDataLoader {

    static let shared = VocabDataLoader()
    private init() {}

    lazy var words: [Word] = parseWords()
    lazy var grammarExamples: [GrammarExample] = parseGrammar()

    // MARK: N2_vocab.csv

    private func parseWords() -> [Word] {
        guard let url = Bundle.main.url(forResource: "N2_vocab", withExtension: "csv"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            print("[VocabDataLoader] ⚠️ N2_vocab.csv 로드 실패")
            return []
        }

        let rows = parseCSV(raw)
        guard let header = rows.first else { return [] }
        let columns = columnIndex(for: header)

        var result: [Word] = []
        for row in rows.dropFirst() {
            guard let kanji = value(in: row, columns: columns, names: ["kanji"]),
                  let reading = value(in: row, columns: columns, names: ["reading"]) else { continue }

            let meanings = localizedColumns(prefix: "meaning", row: row, columns: columns)

            result.append(Word(
                kanji: kanji,
                reading: reading,
                meanings: meanings
            ))
        }
        return result
    }

    // MARK: N2_grammar.csv

    private func parseGrammar() -> [GrammarExample] {
        guard let url = Bundle.main.url(forResource: "N2_grammar", withExtension: "csv"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            print("[VocabDataLoader] ⚠️ N2_grammar.csv 로드 실패")
            return []
        }

        let rows = parseCSV(raw)
        guard let header = rows.first else { return [] }
        let columns = columnIndex(for: header)

        var result: [GrammarExample] = []
        for row in rows.dropFirst() {
            guard let grammar = value(in: row, columns: columns, names: ["grammar"]),
                  let example = value(in: row, columns: columns, names: ["example"]) else { continue }

            result.append(GrammarExample(
                grammar: grammar,
                example: example,
                meanings: localizedColumns(prefix: "meaning", row: row, columns: columns),
                translations: localizedColumns(prefix: "translation", row: row, columns: columns)
            ))
        }
        return result
    }

    private func columnIndex(for header: [String]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: header.enumerated().map { ($0.element.trimmed.lowercased(), $0.offset) })
    }

    private func value(in row: [String], columns: [String: Int], names: [String]) -> String? {
        for name in names {
            guard let index = columns[name], row.indices.contains(index) else { continue }
            let candidate = row[index].trimmed
            if !candidate.isEmpty { return candidate }
        }
        return nil
    }

    private func localizedColumns(
        prefix: String,
        row: [String],
        columns: [String: Int]
    ) -> [String: String] {
        let languageColumns: [(key: String, suffixes: [String])] = [
            ("ko", ["ko"]),
            ("en", ["en"]),
            ("ja", ["ja"]),
            ("zh-Hans", ["zh_hans", "zh"]), // 기존 CSV의 *_zh도 계속 지원
            ("zh-Hant", ["zh_hant"]),
            ("fr", ["fr"]),
            ("id", ["id"]),
            ("es", ["es"]),
            ("th", ["th"]),
            ("vi", ["vi"])
        ]

        return Dictionary(uniqueKeysWithValues: languageColumns.compactMap { language in
            let names = language.suffixes.map { "\(prefix)_\($0)" }
            guard let localizedValue = value(in: row, columns: columns, names: names) else { return nil }
            return (language.key, localizedValue)
        })
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
