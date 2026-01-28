import Foundation

struct AudioDataLoader {

    static func load(set: Int) -> [AudioQuestion] {
        return loadFromCSV(fileName: "jlptn2_audio_set\(set)")
    }
}

extension AudioDataLoader {

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
            .dropFirst()

        var questions: [AudioQuestion] = []

        for (index, row) in rows.enumerated() {
            let columns = parseCSVLine(row)

            // 최소 7개 (question ~ audioFileName)
            guard columns.count >= 7 else {
                print("⚠️ Row \(index + 2) 컬럼 부족")
                continue
            }

            let question = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)

            let options = [
                columns.count > 1 ? columns[1] : "",
                columns.count > 2 ? columns[2] : "",
                columns.count > 3 ? columns[3] : "",
                columns.count > 4 ? columns[4] : ""
            ].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
             .filter { !$0.isEmpty }

            let answer = columns[5].trimmingCharacters(in: .whitespacesAndNewlines)
            let audioFileName = columns[6].trimmingCharacters(in: .whitespacesAndNewlines)

            // ✅ start / end 처리 핵심
            let rawStart = columns.count > 7 ? TimeInterval(columns[7]) : nil
            let rawEnd   = columns.count > 8 ? TimeInterval(columns[8]) : nil

            let startTime: TimeInterval?
            let endTime: TimeInterval?

            if let s = rawStart, let e = rawEnd, e > s {
                startTime = s
                endTime = e
            } else {
                startTime = nil
                endTime = nil
            }

            let imageName = columns.count > 9
                ? columns[9].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                : nil

            let scriptKey = columns.count > 10
                ? columns[10].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                : nil

            if index < 3 {
                print("🎧 Audio \(index + 1)")
                print("Audio:", audioFileName)
                print("start:", startTime as Any, "end:", endTime as Any)
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
                    scriptKey: scriptKey
                )
            )
        }

        print("✅ \(fileName) 로드 완료: \(questions.count)개")
        return questions
    }
}

// MARK: - CSV Parser
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

