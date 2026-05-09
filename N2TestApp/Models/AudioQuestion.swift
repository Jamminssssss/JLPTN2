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
    /// CSV의 script_ko / script_en / script_zh_hans 등을 담는 딕셔너리.
    /// key 예시: "ko", "en", "zh_hans", "zh_hant", "ja", "fr", "id", "es", "th", "vi"
    let scripts: [String: String]?
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
        case scripts
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
        scripts: [String: String]? = nil,
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
        self.scripts = scripts
        self.tappedAnswer = tappedAnswer
    }

    // MARK: - 편의 메서드

    /// 기기 언어에 맞는 스크립트를 반환합니다.
    /// 해당 언어가 없으면 한국어(ko)로 폴백합니다.
    func localizedScript(languageCode: String = Locale.current.language.languageCode?.identifier ?? "ko") -> String? {
        guard let scripts, !scripts.isEmpty else { return nil }
        // zh-Hans / zh-Hant 처리 (언더스코어 키로 저장됨)
        let normalized = languageCode
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        return scripts[normalized] ?? scripts["ko"]
    }
}
