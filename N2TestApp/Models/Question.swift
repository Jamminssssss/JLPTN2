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

    // ✅ 지문 그룹 식별자 (같은 값이면 동일 지문 묶음)
    // CSV 컬럼: passage_group (index 18)
    var passageGroup: String?

    // ✅ 지문 그룹에서 각 문항의 실제 질문 텍스트
    // CSV 컬럼: sub_question (index 19)
    // passageGroup이 있을 때, question 필드는 공유 지문, subQuestion은 해당 문항 질문
    var subQuestion: String?

    // ✅ 다국어 해설 (CSV 컬럼: explanation_ko ~ explanation_vi)
    var explanationKo: String?
    var explanationEn: String?
    var explanationZhHans: String?
    var explanationZhHant: String?
    var explanationJa: String?
    var explanationFr: String?
    var explanationId: String?
    var explanationEs: String?
    var explanationTh: String?
    var explanationVi: String?

    // ✅ 동일 이미지 사용 시 자동 묶음용 그룹 키
    // imageURL이 우선이며, 없으면 imageName 사용. 둘 다 없으면 nil
    var imageGroupKey: String? {
        if let url = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            return "url::\(url)"
        }
        if let name = imageName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return "name::\(name)"
        }
        return nil
    }

    // ✅ 실제 그룹 키: passageGroup이 있으면 우선 사용, 없으면 이미지 기준
    // 외부에서 Dictionary(grouping:by:)에 바로 사용 가능
    var effectiveGroupKey: String? {
        if let pg = passageGroup?.trimmingCharacters(in: .whitespacesAndNewlines), !pg.isEmpty {
            return "passage::\(pg)"
        }
        return imageGroupKey
    }

    /// 기기 언어에 맞는 해설 반환 (없으면 영어 → 한국어 순 폴백)
    var localizedExplanation: String? {
        func nonEmpty(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }

        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let scriptCode = Locale.current.language.script?.identifier

        let en = nonEmpty(explanationEn)
        let ko = nonEmpty(explanationKo)
        let ja = nonEmpty(explanationJa)
        let zhHans = nonEmpty(explanationZhHans)
        let zhHant = nonEmpty(explanationZhHant)
        let fr = nonEmpty(explanationFr)
        let id = nonEmpty(explanationId)
        let es = nonEmpty(explanationEs)
        let th = nonEmpty(explanationTh)
        let vi = nonEmpty(explanationVi)

        switch langCode {
        case "ko": return ko ?? en
        case "ja": return ja ?? en
        case "zh":
            return scriptCode == "Hant"
                ? (zhHant ?? zhHans ?? en)
                : (zhHans ?? en)
        case "fr": return fr ?? en
        case "id": return id ?? en
        case "es": return es ?? en
        case "th": return th ?? en
        case "vi": return vi ?? en
        default:   return en ?? ko
        }
    }

    // ❌ id, tappedAnswer 제외
    enum CodingKeys: String, CodingKey {
        case question
        case imageName
        case imageURL
        case options
        case answer
        case underline
        case passageGroup  = "passage_group"
        case subQuestion   = "sub_question"
        case explanationKo    = "explanation_ko"
        case explanationEn    = "explanation_en"
        case explanationZhHans = "explanation_zh_hans"
        case explanationZhHant = "explanation_zh_hant"
        case explanationJa    = "explanation_ja"
        case explanationFr    = "explanation_fr"
        case explanationId    = "explanation_id"
        case explanationEs    = "explanation_es"
        case explanationTh    = "explanation_th"
        case explanationVi    = "explanation_vi"
    }

    init(question: String? = nil,
         imageName: String? = nil,
         imageURL: String? = nil,
         options: [String],
         answer: String,
         underline: [String] = [],
         passageGroup: String? = nil,
         subQuestion: String? = nil,
         explanationKo: String? = nil,
         explanationEn: String? = nil,
         explanationZhHans: String? = nil,
         explanationZhHant: String? = nil,
         explanationJa: String? = nil,
         explanationFr: String? = nil,
         explanationId: String? = nil,
         explanationEs: String? = nil,
         explanationTh: String? = nil,
         explanationVi: String? = nil) {

        self.question = question
        self.imageName = imageName
        self.imageURL = imageURL
        self.options = options
        self.answer = answer
        self.tappedAnswer = nil
        self.underline = underline
        self.passageGroup = passageGroup
        self.subQuestion = subQuestion
        self.explanationKo = explanationKo
        self.explanationEn = explanationEn
        self.explanationZhHans = explanationZhHans
        self.explanationZhHant = explanationZhHant
        self.explanationJa = explanationJa
        self.explanationFr = explanationFr
        self.explanationId = explanationId
        self.explanationEs = explanationEs
        self.explanationTh = explanationTh
        self.explanationVi = explanationVi
    }
}
