import Foundation

/// Consecutive questions that share one audio segment, with original indices for persistence.
struct AudioQuestionGroup {
    let questions: [AudioQuestion]
    let questionIndices: [Int]

    static func group(_ questions: [AudioQuestion]) -> [AudioQuestionGroup] {
        var groups: [AudioQuestionGroup] = []
        var index = 0
        while index < questions.count {
            let first = questions[index]
            var end = index + 1
            while end < questions.count {
                let next = questions[end]
                guard first.audioFileName == next.audioFileName,
                      first.startTime == next.startTime,
                      first.endTime == next.endTime else { break }
                end += 1
            }
            groups.append(AudioQuestionGroup(
                questions: Array(questions[index..<end]),
                questionIndices: Array(index..<end)
            ))
            index = end
        }
        return groups
    }
}
