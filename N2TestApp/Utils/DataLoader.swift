import Foundation

struct DataLoader {

    // MARK: - Main Entry
    /// set == 1 : Local questions
    /// set >= 2 : CSV questions
    static func load(set: Int) -> [Question] {
        return loadFromCSV(fileName: "jlptn2_reading_set\(set)")
    }
}

// MARK: - CSV Loader (2회 이상)
extension DataLoader {

    /// CSV column order
    /// 0: question
    /// 1~4: options
    /// 5: answer
    /// 6: imageName
    /// 7: underline
    static func loadFromCSV(fileName: String) -> [Question] {

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("❌ Reading CSV load failed: \(fileName).csv")
            return []
        }

        let rows = content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .dropFirst() // header 제거

        var questions: [Question] = []

        for (index, row) in rows.enumerated() {
            let columns = parseCSVLine(row)

            // 최소 6개 컬럼 필요 (question, 4 options, answer)
            guard columns.count >= 6 else {
                print("⚠️ Row \(index + 2) has insufficient columns: \(columns.count)")
                continue
            }

            // CSV 안에서 \n, \n\n 등을 실제 줄바꿈으로 변환
            let question = columns[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\n", with: "\n") // 줄바꿈 변환
                .nilIfEmpty

            // 4개의 개별 옵션 컬럼에서 옵션 수집
            let options = [
                columns[1].trimmingCharacters(in: .whitespacesAndNewlines),
                columns[2].trimmingCharacters(in: .whitespacesAndNewlines),
                columns[3].trimmingCharacters(in: .whitespacesAndNewlines),
                columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
            ].filter { !$0.isEmpty }

            let answer = columns[5].trimmingCharacters(in: .whitespacesAndNewlines)

            // imageName (6번째 컬럼, 인덱스 6)
            let imageName = columns.count > 6 ? columns[6].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil

            // underline (7번째 컬럼, 인덱스 7)
            var underline: [String] = []
            if columns.count > 7 {
                let underlineText = columns[7].trimmingCharacters(in: .whitespacesAndNewlines)
                if !underlineText.isEmpty {
                    let separator = underlineText.contains("|") ? "|" : ","
                    underline = underlineText
                        .components(separatedBy: separator)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                }
            }

            // 디버깅 (처음 3개만)
            if index < 3 {
                print("📝 Question \(index + 1):")
                print("   Text: \(question?.prefix(100) ?? "없음")...")
                print("   Options count: \(options.count)")
                print("   Answer: \(answer)")
                print("   Image: \(imageName ?? "없음")")
                print("   Underline: \(underline)")
                print("---")
            }

            questions.append(
                Question(
                    question: question,
                    imageName: imageName,
                    imageURL: nil,
                    options: options,
                    answer: answer,
                    underline: underline
                )
            )
        }

        print("✅ \(fileName)에서 \(questions.count)개 문제 로드 완료")
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

extension String {
    var nilIfEmpty: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
