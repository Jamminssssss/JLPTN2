import Foundation

struct Question: Identifiable, Codable {

    // ✅ Codable 제외, 로딩 시 자동 생성
    let id = UUID()

    var question: String?
    var imageName: String?
    var imageURL: String?

    // ✅ CSV에서는 "option1|option2|..." 로 들어옴
    var options: [String]
    var answer: String

    // ✅ 사용자 선택 (저장용, CSV엔 없음)
    var tappedAnswer: String?

    // ✅ CSV에서는 "단어1|단어2"
    var underline: [String]

    // ❌ id 제거
    enum CodingKeys: String, CodingKey {
        case question
        case imageName
        case imageURL
        case options
        case answer
        case underline
    }

    init(question: String? = nil,
         imageName: String? = nil,
         imageURL: String? = nil,
         options: [String],
         answer: String,
         underline: [String] = []) {

        self.question = question
        self.imageName = imageName
        self.imageURL = imageURL
        self.options = options
        self.answer = answer
        self.tappedAnswer = nil
        self.underline = underline
    }
}
