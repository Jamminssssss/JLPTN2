import Foundation

// MARK: - QuestionGroup
/// 같은 지문을 공유하는 문제 묶음
struct QuestionGroup: Identifiable {
    let id = UUID()

    /// 그룹 내 문제 배열
    let questions: [Question]

    /// 원본 questions 배열에서의 인덱스 (오답 추적, 진행 저장에 사용)
    let questionIndices: [Int]

    /// 그룹에 문제가 2개 이상인지 여부
    var isMulti: Bool { questions.count > 1 }

    /// 공유 지문 텍스트 (isMulti일 때만 의미 있음)
    /// - isMulti: questions[0].question 이 공유 지문
    /// - single:  nil (question 자체가 내용)
    var sharedPassage: String? {
        isMulti ? questions.first?.question : nil
    }

    var sharedImageName: String? { questions.first?.imageName }
    var sharedUnderline: [String] { questions.first?.underline ?? [] }
}

// MARK: - DataLoader
struct DataLoader {

    // MARK: - Main Entry
    /// set == 1 : Local questions
    /// set >= 2 : CSV questions
    static func load(set: Int) -> [Question] {
        return loadFromCSV(fileName: "jlptn2_reading_set\(set)")
    }

    /// questions 배열을 passageGroup 기준으로 QuestionGroup 배열로 변환
    /// - passageGroup 이 같은 연속된 문제들을 하나의 그룹으로 묶음
    /// - passageGroup 이 없는 문제는 단독 그룹으로 처리
    static func groupQuestions(_ questions: [Question]) -> [QuestionGroup] {
        var groups: [QuestionGroup] = []
        var i = 0

        while i < questions.count {
            let q = questions[i]

            // 1) passageGroup이 있으면 같은 passageGroup을 가진 연속 문제를 묶음
            if let passageId = q.passageGroup, !passageId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                var batch: [(Question, Int)] = [(q, i)]
                var j = i + 1
                while j < questions.count, questions[j].passageGroup == passageId {
                    batch.append((questions[j], j))
                    j += 1
                }
                groups.append(QuestionGroup(
                    questions: batch.map(\.0),
                    questionIndices: batch.map(\.1)
                ))
                i = j
                continue
            }

            // 2) passageGroup이 없고, image/effective 키가 있으면 같은 키의 연속 문제를 묶음
            if let key = q.effectiveGroupKey, !key.isEmpty {
                var batch: [(Question, Int)] = [(q, i)]
                var j = i + 1
                while j < questions.count, questions[j].effectiveGroupKey == key, (questions[j].passageGroup?.isEmpty ?? true) {
                    batch.append((questions[j], j))
                    j += 1
                }
                groups.append(QuestionGroup(
                    questions: batch.map(\.0),
                    questionIndices: batch.map(\.1)
                ))
                i = j
                continue
            }

            // 3) 그 외에는 단독 그룹
            groups.append(QuestionGroup(questions: [q], questionIndices: [i]))
            i += 1
        }

        return groups
    }
}

// MARK: - CSV Loader
extension DataLoader {

    /// CSV column order
    /// 0:  question
    /// 1~4: options
    /// 5:  answer
    /// 6:  imageName
    /// 7:  underline
    /// 8:  explanation_ko
    /// 9:  explanation_en
    /// 10: explanation_zh_hans
    /// 11: explanation_zh_hant
    /// 12: explanation_ja
    /// 13: explanation_fr
    /// 14: explanation_id
    /// 15: explanation_es
    /// 16: explanation_th
    /// 17: explanation_vi
    /// 18: passage_group   ← NEW: 같은 지문 그룹 식별자 (예: "P1", "P2", ...)
    /// 19: sub_question    ← NEW: 지문 그룹 내 각 문항의 실제 질문 텍스트
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
                .replacingOccurrences(of: "\\n", with: "\n")
                .nilIfEmpty

            // 4개의 개별 옵션 컬럼에서 옵션 수집
            let options = [
                columns[1].trimmingCharacters(in: .whitespacesAndNewlines),
                columns[2].trimmingCharacters(in: .whitespacesAndNewlines),
                columns[3].trimmingCharacters(in: .whitespacesAndNewlines),
                columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
            ].filter { !$0.isEmpty }

            let answer = columns[5].trimmingCharacters(in: .whitespacesAndNewlines)

            // imageName (index 6)
            let imageName = columns.count > 6
                ? columns[6].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                : nil

            // underline (index 7)
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

            // ── 다국어 해설 (index 8~17) ─────────────────────────────
            let explanationKo     = columns.count > 8  ? columns[8].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty  : nil
            let explanationEn     = columns.count > 9  ? columns[9].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty  : nil
            let explanationZhHans = columns.count > 10 ? columns[10].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
            let explanationZhHant = columns.count > 11 ? columns[11].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
            let explanationJa     = columns.count > 12 ? columns[12].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
            let explanationFr     = columns.count > 13 ? columns[13].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
            let explanationId     = columns.count > 14 ? columns[14].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
            let explanationEs     = columns.count > 15 ? columns[15].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
            let explanationTh     = columns.count > 16 ? columns[16].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil
            let explanationVi     = columns.count > 17 ? columns[17].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil

            // ── 지문 그룹 (index 18~19) ──────────────────────────────
            let passageGroup = columns.count > 18
                ? columns[18].trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                : nil

            let subQuestion = columns.count > 19
                ? columns[19]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .nilIfEmpty
                : nil

            // 디버깅 (처음 3개만)
            if index < 3 {
                print("📝 Question \(index + 1):")
                print("   Text: \(question?.prefix(100) ?? "없음")...")
                print("   Options count: \(options.count)")
                print("   Answer: \(answer)")
                print("   Image: \(imageName ?? "없음")")
                print("   Underline: \(underline)")
                print("   PassageGroup: \(passageGroup ?? "없음")")
                print("   SubQuestion: \(subQuestion?.prefix(60) ?? "없음")")
                print("   Explanation(en): \(explanationEn?.prefix(60) ?? "없음")")
                print("---")
            }

            questions.append(
                Question(
                    question: question,
                    imageName: imageName,
                    imageURL: nil,
                    options: options,
                    answer: answer,
                    underline: underline,
                    passageGroup: passageGroup,
                    subQuestion: subQuestion,
                    explanationKo: explanationKo,
                    explanationEn: explanationEn,
                    explanationZhHans: explanationZhHans,
                    explanationZhHant: explanationZhHant,
                    explanationJa: explanationJa,
                    explanationFr: explanationFr,
                    explanationId: explanationId,
                    explanationEs: explanationEs,
                    explanationTh: explanationTh,
                    explanationVi: explanationVi
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

// MARK: - String Helper
extension String {
    var nilIfEmpty: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
