import Foundation

struct AudioDataLoader {

    static func load(set: Int) -> [AudioQuestion] {
        return loadFromCSV(fileName: "jlptn2_audio_set\(set)")
    }
}

extension AudioDataLoader {

    // CSV 열 인덱스 상수
    private enum Col {
        static let question     = 0
        static let option1      = 1
        static let option2      = 2
        static let option3      = 3
        static let option4      = 4
        static let answer       = 5
        static let audioFileName = 6
        static let startTime    = 7
        static let endTime      = 8
        static let imageName    = 9
        static let scriptKey    = 10
        // 다국어 스크립트 (CSV에 없으면 자동으로 nil)
        static let script_ko    = 11
        static let script_en    = 12
        static let script_zh_hans = 13
        static let script_zh_hant = 14
        static let script_ja    = 15
        static let script_fr    = 16
        static let script_id    = 17
        static let script_es    = 18
        static let script_th    = 19
        static let script_vi    = 20
    }

    /// script_* 컬럼 인덱스 → 언어 코드 매핑
    private static let scriptColumns: [(index: Int, lang: String)] = [
        (Col.script_ko,     "ko"),
        (Col.script_en,     "en"),
        (Col.script_zh_hans,"zh_hans"),
        (Col.script_zh_hant,"zh_hant"),
        (Col.script_ja,     "ja"),
        (Col.script_fr,     "fr"),
        (Col.script_id,     "id"),
        (Col.script_es,     "es"),
        (Col.script_th,     "th"),
        (Col.script_vi,     "vi"),
    ]

    static func loadFromCSV(fileName: String) -> [AudioQuestion] {

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ Audio CSV load failed: \(fileName).csv")
            return []
        }

        let rows = content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .dropFirst() // 헤더 제거

        var questions: [AudioQuestion] = []

        for (index, row) in rows.enumerated() {
            let columns = parseCSVLine(row)

            // 최소 7개 컬럼 (question ~ audioFileName) 필요
            guard columns.count >= 7 else {
                print("⚠️ Row \(index + 2) 컬럼 부족 (\(columns.count)개)")
                continue
            }

            let question = columns[Col.question].trimmed

            let options = [
                columns.value(at: Col.option1),
                columns.value(at: Col.option2),
                columns.value(at: Col.option3),
                columns.value(at: Col.option4),
            ]
            .map { $0.trimmed }
            .filter { !$0.isEmpty }

            let answer       = columns[Col.answer].trimmed
            let audioFileName = columns[Col.audioFileName].trimmed

            // start / end 처리
            let rawStart = columns.count > Col.startTime ? TimeInterval(columns[Col.startTime].trimmed) : nil
            let rawEnd   = columns.count > Col.endTime   ? TimeInterval(columns[Col.endTime].trimmed)   : nil

            let startTime: TimeInterval?
            let endTime: TimeInterval?
            if let s = rawStart, let e = rawEnd, e > s {
                startTime = s
                endTime   = e
            } else {
                startTime = nil
                endTime   = nil
            }

            let imageName = columns.nilIfEmpty(at: Col.imageName)
            let scriptKey = columns.nilIfEmpty(at: Col.scriptKey)

            // ── 다국어 스크립트 딕셔너리 구성 (일본어 기본, 다른 언어 비어있으면 일본어로 대체) ──
            var scripts: [String: String] = [:]

            // 1) 우선 CSV에 있는 값들만 채움
            for entry in scriptColumns {
                if let text = columns.nilIfEmpty(at: entry.index) {
                    scripts[entry.lang] = text.replacingOccurrences(of: "\\n", with: "\n")
                }
            }

            // 2) 일본어 스크립트를 기본값으로 확보 (CSV의 ja 컬럼 또는 scriptKey가 ja인 경우를 대비)
            let japaneseText: String? = {
                if let ja = scripts["ja"], !ja.isEmpty { return ja }
                // 추가적인 소스가 있다면 여기서 확장 가능 (예: scriptKey로 별도 리소스 조회)
                return nil
            }()

            // 3) 일본어가 존재하면, 비어있는 언어는 일본어로 fallback
            if let ja = japaneseText, !ja.isEmpty {
                for (_, lang) in scriptColumns.map({ ($0.index, $0.lang) }) {
                    // CSV에 값이 없거나 공백이면 일본어로 채움
                    let existing = scripts[lang]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if existing.isEmpty {
                        // 해당 컬럼이 실제로 존재했는지 여부와 상관 없이, 조회 시 비어 있으면 일본어로 대체
                        // (나중에 CSV에 값이 추가되면 그 값이 우선 적용됨)
                        scripts[lang] = ja
                    }
                }
            }

            let scriptsOrNil: [String: String]? = scripts.isEmpty ? nil : scripts

            if index < 3 {
                print("🎧 Audio \(index + 1)")
                print("  audio : \(audioFileName)")
                print("  start : \(startTime as Any)  end: \(endTime as Any)")
                print("  scripts: \(scripts.keys.sorted())")
            }

            questions.append(
                AudioQuestion(
                    question: question,
                    options: options,
                    answer: answer,
                    audioFileName: audioFileName,
                    startTime: startTime,
                    endTime: endTime,
                    imageName: imageName,
                    scriptKey: scriptKey,
                    scripts: scriptsOrNil
                )
            )
        }

        print("✅ \(fileName) 로드 완료: \(questions.count)개")
        return questions
    }
}

// MARK: - Array 편의 확장

private extension Array where Element == String {
    func value(at index: Int) -> String {
        guard index < count else { return "" }
        return self[index]
    }

    func nilIfEmpty(at index: Int) -> String? {
        guard index < count else { return nil }
        let s = self[index].trimmed
        return s.isEmpty ? nil : s
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - CSV 파서

private func parseCSVLine(_ line: String) -> [String] {
    var result: [String] = []
    var current = ""
    var insideQuotes = false

    for char in line {
        if char == "\"" {
            insideQuotes.toggle()
        } else if char == "," && !insideQuotes {
            result.append(current)
            current = ""
        } else {
            current.append(char)
        }
    }

    result.append(current)
    return result
}
