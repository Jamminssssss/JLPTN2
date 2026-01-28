import Foundation

struct AudioQuestion: Identifiable, Codable {
    let id: UUID
    let question: String
    let options: [String]
    let answer: String
    let audioFileName: String
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    let imageName: String?
    let scriptKey: String?
    var tappedAnswer: String?

    enum CodingKeys: String, CodingKey {
        case id
        case question
        case options
        case answer
        case audioFileName
        case startTime
        case endTime
        case imageName
        case scriptKey
        case tappedAnswer
    }

    init(
        id: UUID = UUID(),
        question: String,
        options: [String],
        answer: String,
        audioFileName: String,
        startTime: TimeInterval? = nil,
        endTime: TimeInterval? = nil,
        imageName: String? = nil,
        scriptKey: String? = nil,
        tappedAnswer: String? = nil
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.answer = answer
        self.audioFileName = audioFileName
        self.startTime = startTime
        self.endTime = endTime
        self.imageName = imageName
        self.scriptKey = scriptKey
        self.tappedAnswer = tappedAnswer
    }
}
