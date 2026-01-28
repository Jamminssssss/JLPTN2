import Foundation

struct GrammarExample: Codable {
    let grammar: String
    let example: String
    let meanings: [String: String]
    let translations: [String: String]

    static let examples: [GrammarExample] = [
        GrammarExample(
            grammar: "あげく",
            example: "色々悩んだあげく、大学院に進学することにした。",
            meanings: [
                "en": "to end up; in the end; finally; after all ~ (often with a negative or unexpected outcome, or after much effort)",
                "ko": "결국; ~한 끝에 (주로 부정적이거나 예상치 못한 결과, 또는 많은 노력 끝에)",
                "zh": "结果；最终；到头来 (多指不好的或意外的结果，或经过很多努力之后)",
                "th": "ลงท้ายด้วย; ในที่สุด; ผลสุดท้าย (มักจะเป็นผลลัพธ์ที่ไม่ดีหรือไม่คาดคิด หรือหลังพยายามอย่างมาก)",
                "vi": "cuối cùng thì; kết cục là; rốt cuộc (thường với kết quả tiêu cực, không mong đợi, hoặc sau nhiều nỗ lực)"
            ],
            translations: [
                "en": "After worrying a lot, I ended up deciding to go to graduate school.",
                "ko": "여러 가지로 고민한 끝에, 대학원에 진학하기로 했다.",
                "zh": "经过反复思考，最终决定去读研究生院。",
                "th": "หลังจากกังวลอยู่นาน ในที่สุดก็ตัดสินใจเรียนต่อปริญญาโท",
                "vi": "Sau nhiều trăn trở, cuối cùng tôi đã quyết định học cao học."
            ]
        ),
        GrammarExample(
            grammar: "あるいは",
            example: "会議は明日、あるいは明後日になるでしょう。",
            meanings: [
                "en": "or; either; maybe; perhaps; possibly ~",
                "ko": "또는; 혹은; 어쩌면; 아마도 ~",
                "zh": "或者；抑或；也许；可能 ~",
                "th": "หรือ; หรือไม่ก็; อาจจะ; บางที ~",
                "vi": "hoặc là; hay là; có lẽ; có thể ~"
            ],
            translations: [
                "en": "The meeting will probably be tomorrow, or perhaps the day after tomorrow.",
                "ko": "회의는 내일, 혹은 모레가 될 것입니다.",
                "zh": "会议大概是明天，或者后天吧。",
                "th": "การประชุมอาจจะเป็นวันพรุ่งนี้ หรือไม่ก็วันมะรืน",
                "vi": "Cuộc họp có lẽ sẽ diễn ra vào ngày mai, hoặc có thể là ngày kia."
            ]
        ),
        GrammarExample(
            grammar: "ばかり",
            example: "彼は漫画ばかり読んでいる。",
            meanings: [
                "en": "only; just; nothing but; about, approximately ~",
                "ko": "정도; 쯤; 뿐; 만 ~",
                "zh": "左右；上下；光是；净是 ~",
                "th": "ประมาณ; ราวๆ; เพียงแค่; เอาแต่ ~",
                "vi": "khoảng; chừng; chỉ; toàn là ~"
            ],
            translations: [
                "en": "He does nothing but read manga.",
                "ko": "그는 만화만 읽고 있다.",
                "zh": "他光看漫画。",
                "th": "เขาเอาแต่อ่านการ์ตูน",
                "vi": "Anh ấy chỉ toàn đọc truyện tranh."
            ]
        ),
        GrammarExample(
            grammar: "ばかりだ",
            example: "状況は悪くなるばかりだ。",
            meanings: [
                "en": "continue to (go in negative direction); only X left to do",
                "ko": "~하기만 하다 (주로 부정적인 방향으로 계속됨); ~할 뿐이다",
                "zh": "一个劲儿地（往坏方向发展）；只剩下（做某事）",
                "th": "มีแต่จะ... (ไปในทางที่ไม่ดี); เหลือแค่...เท่านั้น",
                "vi": "cứ (theo chiều hướng tiêu cực); chỉ còn (việc X phải làm)"
            ],
            translations: [
                "en": "The situation is just getting worse.",
                "ko": "상황은 나빠지기만 한다.",
                "zh": "情况一个劲儿地变坏。",
                "th": "สถานการณ์มีแต่จะแย่ลง",
                "vi": "Tình hình cứ thế xấu đi."
            ]
        ),
        GrammarExample(
            grammar: "ばかりか",
            example: "彼は英語ばかりか、フランス語も話せる。",
            meanings: [
                "en": "not only... but also; as well as ~",
                "ko": "~뿐만 아니라 ~도",
                "zh": "不仅…而且…；不光…还…",
                "th": "ไม่ใช่แค่...แต่ยัง...อีกด้วย",
                "vi": "không những...mà còn..."
            ],
            translations: [
                "en": "He can speak not only English but also French.",
                "ko": "그는 영어뿐만 아니라 프랑스어도 할 수 있다.",
                "zh": "他不仅会说英语，而且还会说法语。",
                "th": "เขาไม่ใช่แค่พูดภาษาอังกฤษได้ แต่ยังพูดภาษาฝรั่งเศสได้ด้วย",
                "vi": "Anh ấy không những nói được tiếng Anh mà còn nói được cả tiếng Pháp."
            ]
        ),
        GrammarExample(
            grammar: "ばかりに",
            example: "正直に言ったばかりに、彼を怒らせてしまった。",
            meanings: [
                "en": "simply because; on account of~ (negative result)",
                "ko": "~하는 바람에; ~탓에 (부정적인 결과)",
                "zh": "只因为…；就因为…（导致不好的结果）",
                "th": "เพียงเพราะว่า...; ด้วยเหตุที่ว่า... (ผลลัพธ์ที่ไม่ดี)",
                "vi": "chỉ vì; tại vì (dẫn đến kết quả tiêu cực)"
            ],
            translations: [
                "en": "Simply because I spoke honestly, I made him angry.",
                "ko": "솔직하게 말한 탓에 그를 화나게 만들었다.",
                "zh": "就因为说了实话，把他给惹生气了。",
                "th": "เพียงเพราะพูดความจริงออกไป ก็เลยทำให้เขาโกรธ",
                "vi": "Chỉ vì nói thật mà tôi đã làm anh ấy tức giận."
            ]
        ),
        GrammarExample(
            grammar: "ちなみに",
            example: "これは新製品です。ちなみに、旧モデルは半額です。",
            meanings: [
                "en": "by the way; in this connection; incidentally; (conjunction)",
                "ko": "덧붙여 말하자면; 참고로; 그런데 (접속사)",
                "zh": "顺便一提；就此而言；另外 (连词)",
                "th": "อนึ่ง; อีกอย่าง; ว่าแต่ (คำเชื่อม)",
                "vi": "nhân tiện; nói thêm là; à mà (liên từ)"
            ],
            translations: [
                "en": "This is a new product. By the way, the old model is half price.",
                "ko": "이것은 신제품입니다. 참고로, 구형 모델은 반값입니다.",
                "zh": "这是新产品。顺便说一下，旧型号是半价。",
                "th": "นี่คือผลิตภัณฑ์ใหม่ อนึ่ง รุ่นเก่าลดราคาครึ่งหนึ่งครับ",
                "vi": "Đây là sản phẩm mới. Nhân tiện, mẫu cũ đang được giảm nửa giá."
            ]
        ),
        GrammarExample(
            grammar: "ちっとも～ない",
            example: "彼は私の話をちっとも聞いていなかった。",
            meanings: [
                "en": "(not) at all; (not) in the least ~",
                "ko": "조금도 ~않다; 전혀 ~않다",
                "zh": "一点也（不）～；毫（不）～",
                "th": "(ไม่)...เลยสักนิด; (ไม่)...เลยแม้แต่น้อย",
                "vi": "không...chút nào; chẳng...tí nào"
            ],
            translations: [
                "en": "He wasn't listening to my story at all.",
                "ko": "그는 내 이야기를 조금도 듣고 있지 않았다.",
                "zh": "他一点也没听我说话。",
                "th": "เขาไม่ได้ฟังเรื่องของฉันเลยสักนิด",
                "vi": "Anh ấy chẳng nghe tôi nói chút nào cả."
            ]
        ),
        GrammarExample(
            grammar: "だけあって",
            example: "さすがプロだけあって、彼の料理は素晴らしい。",
            meanings: [
                "en": "being the case; precisely because; as expected from ~",
                "ko": "~인 만큼; ~답게; 과연 ~이다 보니",
                "zh": "不愧是…；正因为…；到底是…",
                "th": "สมกับที่เป็น...; ก็เพราะว่าเป็น...; อย่างที่คาดไว้จาก...",
                "vi": "đúng là; quả là; chính vì là..."
            ],
            translations: [
                "en": "As expected from a professional, his cooking is wonderful.",
                "ko": "역시 프로인 만큼 그의 요리는 훌륭하다.",
                "zh": "不愧是专业人士，他做的菜很棒。",
                "th": "สมกับที่เป็นมืออาชีพ อาหารของเขายอดเยี่ยมมาก",
                "vi": "Đúng là dân chuyên nghiệp, món ăn anh ấy nấu thật tuyệt vời."
            ]
        ),
        GrammarExample(
            grammar: "だけましだ",
            example: "給料は安いけど、仕事があるだけましだ。",
            meanings: [
                "en": "it’s better than; one should feel grateful for ~",
                "ko": "~인 것만 해도 다행이다; ~인 것만으로도 낫다",
                "zh": "还算好的；总比…强；值得庆幸的是…",
                "th": "ก็ยังดีกว่า...; ควรจะรู้สึกขอบคุณสำหรับ...",
                "vi": "vẫn còn tốt chán; nên cảm thấy biết ơn vì..."
            ],
            translations: [
                "en": "The salary is low, but it's better than nothing to have a job.",
                "ko": "월급은 적지만, 일이 있는 것만 해도 다행이다.",
                "zh": "虽然工资低，但有工作就算不错了。",
                "th": "ถึงเงินเดือนจะน้อย แต่ก็ยังดีที่มีงานทำ",
                "vi": "Lương thì thấp thật, nhưng có việc làm là vẫn còn may."
            ]
        ),
        GrammarExample(
            grammar: "だけに",
            example: "一生懸命勉強しただけに、合格して本当に嬉しい。",
            meanings: [
                "en": "being the case; precisely because; as one would expect; all the more for that reason",
                "ko": "~인 만큼; ~이기 때문에 더욱더",
                "zh": "正因为…所以更…；（也）怪不得…",
                "th": "ก็เพราะว่า...จึงยิ่ง...; สมกับที่เป็น...",
                "vi": "chính vì...nên càng...; quả đúng là..."
            ],
            translations: [
                "en": "Precisely because I studied so hard, I'm really happy I passed.",
                "ko": "열심히 공부한 만큼, 합격해서 정말 기쁘다.",
                "zh": "正因为努力学习了，所以考上了真的很高兴。",
                "th": "ก็เพราะตั้งใจเรียนอย่างหนัก ถึงได้ดีใจมากที่สอบผ่าน",
                "vi": "Chính vì đã học hành chăm chỉ nên tôi thực sự vui khi đỗ."
            ]
        ),
        GrammarExample(
            grammar: "だけのことはある",
            example: "このホテルは高いだけのことはある。サービスが素晴らしい。",
            meanings: [
                "en": "no wonder; as expected of; not ... for nothing; not ... with nothing to show for it; it's worth it",
                "ko": "~만 한 가치가 있다; 괜히 ~한 게 아니다",
                "zh": "不愧是…；果然名不虚传；值得…",
                "th": "สมราคา; ไม่เสียแรงที่...; คุ้มค่ากับ...",
                "vi": "quả là đáng đồng tiền bát gạo; bõ công; không hổ danh"
            ],
            translations: [
                "en": "This hotel is expensive, but it's worth it. The service is excellent.",
                "ko": "이 호텔은 비싼 만큼 가치가 있다. 서비스가 훌륭하다.",
                "zh": "这家酒店贵是贵，但确实物有所值。服务很棒。",
                "th": "โรงแรมนี้แพงสมราคาจริงๆ บริการยอดเยี่ยมมาก",
                "vi": "Khách sạn này đắt nhưng đáng tiền. Dịch vụ tuyệt vời."
            ]
        ),
        GrammarExample(
            grammar: "だけは",
            example: "できるだけのことはやった。あとは結果を待つだけだ。",
            meanings: [
                "en": "to do all that one can; at least; if only ~",
                "ko": "~만큼은; ~만은 (최선을 다하다, 최소한)",
                "zh": "尽力（做某事）；至少；只要 ~",
                "th": "ทำเท่าที่ทำได้; อย่างน้อยที่สุด; เพียงแค่ ~",
                "vi": "làm hết sức có thể; ít nhất; chỉ cần ~"
            ],
            translations: [
                "en": "I've done all I can. Now I just have to wait for the results.",
                "ko": "할 수 있는 만큼은 다 했다. 이제 결과를 기다릴 뿐이다.",
                "zh": "能做的都做了。接下来只等结果了。",
                "th": "ฉันทำทุกอย่างที่ทำได้แล้ว ที่เหลือก็แค่รอผลลัพธ์",
                "vi": "Tôi đã làm tất cả những gì có thể. Giờ chỉ còn chờ kết quả."
            ]
        ),
        GrammarExample(
            grammar: "だって",
            example: "「なぜ学校へ行かないの？」「だって、気分が悪いんだもん。」",
            meanings: [
                "en": "because; but; after all; even; too",
                "ko": "왜냐하면; 하지만; 그렇지만; ~도; ~조차도",
                "zh": "因为；可是；毕竟；就连；也",
                "th": "ก็เพราะว่า; แต่ว่า; อย่างไรก็ตาม; แม้แต่; ด้วย",
                "vi": "bởi vì; nhưng mà; dù sao thì; ngay cả; cũng"
            ],
            translations: [
                "en": "\"Why aren't you going to school?\" \"Because I don't feel well.\"",
                "ko": "\"왜 학교에 안 가니?\" \"왜냐하면, 기분이 안 좋단 말이야.\"",
                "zh": "“为什么不去学校？” “因为，我不舒服嘛。”",
                "th": "\"ทำไมไม่ไปโรงเรียนล่ะ\" \"ก็เพราะว่ารู้สึกไม่สบายนี่นา\"",
                "vi": "\"Sao con không đi học?\" \"Tại vì... con thấy không khỏe.\""
            ]
        ),
        GrammarExample(
            grammar: "でしかない",
            example: "これはただの夢でしかない。",
            meanings: [
                "en": "merely; nothing but; no more than; there is only ~",
                "ko": "~에 지나지 않다; ~일 뿐이다",
                "zh": "只不过是…；无非是…；充其量是…",
                "th": "เป็นเพียงแค่...; ไม่มีอะไรมากไปกว่า...; อย่างมากก็แค่...",
                "vi": "chẳng qua chỉ là; không hơn không kém; cùng lắm chỉ là"
            ],
            translations: [
                "en": "This is nothing but a dream.",
                "ko": "이것은 단지 꿈에 지나지 않는다.",
                "zh": "这只不过是个梦罢了。",
                "th": "นี่มันเป็นเพียงแค่ความฝันเท่านั้น",
                "vi": "Đây chẳng qua chỉ là một giấc mơ."
            ]
        ),
        GrammarExample(
            grammar: "どころではない",
            example: "忙しくて、昼ごはんを食べるどころではなかった。",
            meanings: [
                "en": "not the time for; not the place for; far from; anything but ~",
                "ko": "~할 상황이 아니다; ~할 때가 아니다; ~은커녕",
                "zh": "不是…的时候（场合）；远非…；谈不上…",
                "th": "ไม่ใช่เวลาที่จะ...; ไม่ใช่สถานการณ์ที่จะ...; อย่าว่าแต่...",
                "vi": "không phải lúc để...; đâu phải hoàn cảnh để...; nói gì đến..."
            ],
            translations: [
                "en": "I was so busy, it wasn't the time for eating lunch (I couldn't even think about lunch).",
                "ko": "바빠서 점심을 먹을 상황이 아니었다.",
                "zh": "忙得连午饭都顾不上吃。",
                "th": "ยุ่งมากจนไม่มีเวลากินข้าวกลางวันเลย (อย่าว่าแต่กินข้าวกลางวันเลย)",
                "vi": "Tôi bận đến nỗi không phải là lúc để ăn trưa (còn chẳng nghĩ đến bữa trưa được)."
            ]
        ),
        GrammarExample(
            grammar: "どころか",
            example: "彼は謝るどころか、逆に私を非難した。",
            meanings: [
                "en": "far from; anything but; let alone; not to mention; much less ~",
                "ko": "~은커녕; ~은 고사하고; 오히려",
                "zh": "不仅不…反而…；别说…就连…；远非…",
                "th": "อย่าว่าแต่...เลย; ไม่เพียงแต่จะไม่...แต่กลับ...",
                "vi": "đừng nói đến...; nói gì đến...; không những không...mà ngược lại..."
            ],
            translations: [
                "en": "Far from apologizing, he criticized me instead.",
                "ko": "그는 사과하기는커녕 오히려 나를 비난했다.",
                "zh": "他非但没有道歉，反而指责我。",
                "th": "เขาไม่เพียงแต่จะไม่ขอโทษ แต่กลับตำหนิฉันเสียอีก",
                "vi": "Anh ta không những không xin lỗi mà ngược lại còn chỉ trích tôi."
            ]
        ),
        GrammarExample(
            grammar: "どうやら",
            example: "どうやら雨が降りそうだ。",
            meanings: [
                "en": "possibly; apparently; seems like; somehow; barely ~",
                "ko": "아무래도; 어쩐지; 보아하니; 간신히 ~",
                "zh": "总觉得；看起来；好不容易；勉强 ~",
                "th": "ดูเหมือนว่า; เห็นทีว่า; อย่างไรก็ตาม; 겨우 ~",
                "vi": "có vẻ như; hình như; dường như; bằng cách nào đó; بالكاد ~"
            ],
            translations: [
                "en": "It seems like it's going to rain.",
                "ko": "아무래도 비가 올 것 같다.",
                "zh": "看起来要下雨了。",
                "th": "ดูเหมือนว่าฝนจะตกนะ",
                "vi": "Có vẻ như trời sắp mưa."
            ]
        ),
        GrammarExample(
            grammar: "どうせ",
            example: "どうせ失敗するなら、やってみよう。",
            meanings: [
                "en": "anyhow; in any case; at any rate; after all; no matter what",
                "ko": "어차피; 아무튼; 어쨌든",
                "zh": "反正；总归；横竖",
                "th": "อย่างไรก็ตาม; ถึงอย่างไรก็; ไหนๆ ก็",
                "vi": "đằng nào thì; dù sao thì; rốt cuộc"
            ],
            translations: [
                "en": "If I'm going to fail anyway, I might as well try.",
                "ko": "어차피 실패할 거라면, 한번 해보자.",
                "zh": "反正都要失败，不如试一试。",
                "th": "ถ้ายังไงก็จะล้มเหลวอยู่แล้ว ก็ลองดูสักตั้งเถอะ",
                "vi": "Đằng nào cũng thất bại, thì cứ thử xem sao."
            ]
        ),
        GrammarExample(
            grammar: "得ない / えない",
            example: "この問題の解決は、専門家の協力なしにはあり得ない。",
            meanings: [
                "en": "unable to; cannot; it is not possible to ~",
                "ko": "~할 수 없다; 불가능하다",
                "zh": "不能；不可能；无法 ~",
                "th": "ไม่สามารถที่จะ...; เป็นไปไม่ได้ที่จะ...",
                "vi": "không thể; không có khả năng ~"
            ],
            translations: [
                "en": "Solving this problem is impossible without the cooperation of experts.",
                "ko": "이 문제의 해결은 전문가의 협력 없이는 있을 수 없다.",
                "zh": "这个问题没有专家的协助是不可能解决的。",
                "th": "การแก้ปัญหานี้เป็นไปไม่ได้หากไม่ได้รับความร่วมมือจากผู้เชี่ยวชาญ",
                "vi": "Việc giải quyết vấn đề này là không thể nếu không có sự hợp tác của các chuyên gia."
            ]
        ),
        GrammarExample(
            grammar: "得る / える / うる",
            example: "それは十分にあり得ることだ。",
            meanings: [
                "en": "can; to be able to; is possible to ~",
                "ko": "~할 수 있다; 가능하다",
                "zh": "能；可以；可能 ~",
                "th": "สามารถ...ได้; เป็นไปได้ที่จะ...",
                "vi": "có thể; có khả năng ~"
            ],
            translations: [
                "en": "That is something that could very well happen.",
                "ko": "그것은 충분히 있을 수 있는 일이다.",
                "zh": "那是完全可能发生的事。",
                "th": "นั่นเป็นเรื่องที่สามารถเกิดขึ้นได้เสมอ",
                "vi": "Đó là điều hoàn toàn có thể xảy ra."
            ]
        ),
        GrammarExample(
            grammar: "再び / ふたたび",
            example: "彼は再び日本を訪れたいと思っている。",
            meanings: [
                "en": "again; once more",
                "ko": "다시; 재차",
                "zh": "再次；又一次",
                "th": "อีกครั้ง; อีกหน",
                "vi": "lại; một lần nữa"
            ],
            translations: [
                "en": "He wants to visit Japan again.",
                "ko": "그는 다시 일본을 방문하고 싶어한다.",
                "zh": "他想再次访问日本。",
                "th": "เขาอยากจะไปเยือนญี่ปุ่นอีกครั้ง",
                "vi": "Anh ấy muốn đến thăm Nhật Bản một lần nữa."
            ]
        ),
        GrammarExample(
            grammar: "ふうに",
            example: "子供たちは楽しそうなふうに遊んでいた。",
            meanings: [
                "en": "this way; that way; in such a way; how; like; as if",
                "ko": "~한 방식으로; ~처럼; ~듯이",
                "zh": "这样地；那样地；以…方式；好像",
                "th": "ในลักษณะที่...; แบบ...; ราวกับว่า...",
                "vi": "theo kiểu; theo cách; dường như; như thể"
            ],
            translations: [
                "en": "The children were playing in a way that looked fun.",
                "ko": "아이들은 즐거워 보이는 방식으로 놀고 있었다.",
                "zh": "孩子们玩得很开心的样子。",
                "th": "เด็กๆ กำลังเล่นกันในท่าทางที่ดูสนุกสนาน",
                "vi": "Lũ trẻ đang chơi đùa có vẻ rất vui."
            ]
        ),
        GrammarExample(
            grammar: "がきっかけで / をきっかけに",
            example: "アニメがきっかけで、日本語の勉強を始めた。",
            meanings: [
                "en": "with… as a start; as a result of; taking advantage of ~; triggered by",
                "ko": "~을 계기로; ~이 계기가 되어",
                "zh": "以…为契机；由于…的缘故；借…机会",
                "th": "โดยมี...เป็นจุดเริ่มต้น; เนื่องจาก...; ถือโอกาสที่...",
                "vi": "nhờ...mà; nhân dịp...; khởi đầu từ..."
            ],
            translations: [
                "en": "Anime was the trigger for me to start studying Japanese.",
                "ko": "애니메이션을 계기로 일본어 공부를 시작했다.",
                "zh": "因为动画片这个契机，我开始学习日语了。",
                "th": "ฉันเริ่มเรียนภาษาญี่ปุ่นโดยมีอนิเมะเป็นจุดเริ่มต้น",
                "vi": "Nhờ có anime mà tôi bắt đầu học tiếng Nhật."
            ]
        ),
        GrammarExample(
            grammar: "げ",
            example: "彼は何か言いたげな顔をしていた。",
            meanings: [
                "en": "looks like; seems like; appears to ~ (usually with adjectives or verbs showing emotion/state)",
                "ko": "~한 듯한; ~해 보이는 (주로 감정이나 상태를 나타내는 형용사나 동사와 함께 사용)",
                "zh": "好像…的样子；似乎… (通常与表示情感或状态的形容词或动词连用)",
                "th": "ดูเหมือนว่า...; ท่าทาง... (มักใช้กับคำคุณศัพท์หรือคำกริยาที่แสดงอารมณ์/สภาวะ)",
                "vi": "có vẻ; dường như; trông như ~ (thường dùng với tính từ hoặc động từ chỉ cảm xúc/trạng thái)"
            ],
            translations: [
                "en": "He had a look on his face as if he wanted to say something.",
                "ko": "그는 무언가 말하고 싶어하는 얼굴을 하고 있었다.",
                "zh": "他脸上带着想说什么似的表情。",
                "th": "เขทำหน้าเหมือนอยากจะพูดอะไรบางอย่าง",
                "vi": "Anh ấy có vẻ mặt như muốn nói điều gì đó."
            ]
        ),
        GrammarExample(
            grammar: "逆に / ぎゃくに",
            example: "努力したが、逆に成績が下がってしまった。",
            meanings: [
                "en": "conversely; on the contrary ~",
                "ko": "반대로; 거꾸로",
                "zh": "反过来；相反地",
                "th": "ในทางกลับกัน; ตรงกันข้าม",
                "vi": "ngược lại; trái lại"
            ],
            translations: [
                "en": "I worked hard, but on the contrary, my grades went down.",
                "ko": "노력했지만, 반대로 성적이 떨어져 버렸다.",
                "zh": "虽然努力了，但成绩反而下降了。",
                "th": "พยายามแล้ว แต่ผลการเรียนกลับแย่ลงเสียอีก",
                "vi": "Tôi đã cố gắng, nhưng ngược lại, thành tích lại giảm sút."
            ]
        ),
        GrammarExample(
            grammar: "反面 / はんめん",
            example: "都会の生活は便利な反面、ストレスも多い。",
            meanings: [
                "en": "while, although; on the other hand~",
                "ko": "반면; 한편으로는",
                "zh": "另一方面；反过来说",
                "th": "ในทางกลับกัน; ในขณะที่; แต่อีกด้านหนึ่ง",
                "vi": "mặt khác; tuy nhiên"
            ],
            translations: [
                "en": "While city life is convenient, on the other hand, it's also very stressful.",
                "ko": "도시 생활은 편리한 반면, 스트레스도 많다.",
                "zh": "城市生活虽然方便，但另一方面压力也很大。",
                "th": "ชีวิตในเมืองสะดวกสบายก็จริง แต่อีกด้านหนึ่งก็มีความเครียดมาก",
                "vi": "Cuộc sống thành thị tiện lợi, nhưng mặt khác cũng rất nhiều căng thẳng."
            ]
        ),
        GrammarExample(
            grammar: "果たして / はたして",
            example: "果たして彼の話は本当だろうか。",
            meanings: [
                "en": "as was expected; sure enough; really; actually; (in questions) I wonder if...",
                "ko": "과연; 정말로; 실제로; (의문문에서) 과연 ~일까",
                "zh": "果真；果然；究竟；到底；（疑问句中）到底是否…",
                "th": "จริงหรือ; แท้จริงแล้ว; (ในคำถาม) จริงๆ แล้ว...หรือไม่นะ",
                "vi": "quả thực; thật sự; rút cục; (trong câu hỏi) liệu có thật là..."
            ],
            translations: [
                "en": "I wonder if his story is really true.",
                "ko": "과연 그의 이야기는 사실일까?",
                "zh": "他的话究竟是不是真的呢？",
                "th": "เรื่องที่เขาพูดเป็นความจริงหรือเปล่านะ",
                "vi": "Liệu câu chuyện của anh ấy có thật không nhỉ?"
            ]
        ),
        GrammarExample(
            grammar: "一応 / いちおう",
            example: "一応、宿題は終わらせました。",
            meanings: [
                "en": "more or less; pretty much; roughly; tentatively; for the time being; just in case",
                "ko": "일단; 우선; 대강; 어느 정도",
                "zh": "姑且；暂且；大致；勉强",
                "th": "ก็ประมาณหนึ่ง; คร่าวๆ; ในระดับหนึ่ง; เบื้องต้น; เผื่อไว้",
                "vi": "tạm thời; đại khái; ít nhiều; sơ qua; phòng khi"
            ],
            translations: [
                "en": "I've finished my homework, more or less.",
                "ko": "일단 숙제는 끝냈습니다.",
                "zh": "作业姑且是做完了。",
                "th": "การบ้านก็ทำเสร็จแล้วประมาณหนึ่งครับ",
                "vi": "Tôi cũng đã làm xong bài tập về nhà rồi (đại khái là xong)."
            ]
        ),
        GrammarExample(
            grammar: "以外 / いがい",
            example: "関係者以外、立ち入り禁止です。",
            meanings: [
                "en": "with the exception of; excepting; other than",
                "ko": "~이외에; ~을 제외하고",
                "zh": "以外；除…之外",
                "th": "ยกเว้น; นอกเหนือจาก",
                "vi": "ngoài; ngoại trừ"
            ],
            translations: [
                "en": "No entry except for authorized personnel.",
                "ko": "관계자 이외에는 출입 금지입니다.",
                "zh": "非相关人员禁止入内。",
                "th": "ห้ามบุคคลภายนอกเข้า ยกเว้นผู้เกี่ยวข้อง",
                "vi": "Cấm vào cửa, ngoại trừ những người có liên quan."
            ]
        ),
        GrammarExample(
            grammar: "以上に / いじょうに",
            example: "彼は私が想像した以上に親切だった。",
            meanings: [
                "en": "more than; not less than; beyond ~",
                "ko": "~이상으로; ~보다 더",
                "zh": "比…更；超出…",
                "th": "มากกว่า...; เกินกว่า...",
                "vi": "hơn cả; vượt quá ~"
            ],
            translations: [
                "en": "He was kinder than I had imagined.",
                "ko": "그는 내가 상상한 이상으로 친절했다.",
                "zh": "他比我想象的还要亲切。",
                "th": "เขาใจดีเกินกว่าที่ฉันจินตนาการไว้เสียอีก",
                "vi": "Anh ấy tốt bụng hơn cả tôi tưởng tượng."
            ]
        ),
        GrammarExample(
            grammar: "以上は / いじょうは",
            example: "約束した以上は、守らなければならない。",
            meanings: [
                "en": "because; since; seeing that; now that ~",
                "ko": "~한 이상; ~인 한에는",
                "zh": "既然…就…；因为…所以…",
                "th": "ในเมื่อ...แล้ว; เนื่องจากว่า...",
                "vi": "một khi đã...thì; bởi vì; do đó"
            ],
            translations: [
                "en": "Now that I've made a promise, I must keep it.",
                "ko": "약속한 이상은 지켜야 한다.",
                "zh": "既然约定了，就必须遵守。",
                "th": "ในเมื่อสัญญาแล้ว ก็ต้องรักษาสัญญา",
                "vi": "Một khi đã hứa thì phải giữ lời."
            ]
        ),
        GrammarExample(
            grammar: "いきなり",
            example: "彼はいきなり大声で笑い出した。",
            meanings: [
                "en": "abruptly; suddenly; all of a sudden; without warning",
                "ko": "갑자기; 느닷없이; 별안간",
                "zh": "突然；冷不防；猛地",
                "th": "ทันใดนั้น; อยู่ๆ ก็; กะทันหัน",
                "vi": "đột ngột; bất thình lình; bất ngờ"
            ],
            translations: [
                "en": "He suddenly burst out laughing loudly.",
                "ko": "그는 갑자기 큰 소리로 웃기 시작했다.",
                "zh": "他突然大声笑了起来。",
                "th": "อยู่ๆ เขาก็หัวเราะเสียงดังออกมา",
                "vi": "Anh ấy đột nhiên phá lên cười lớn."
            ]
        ),

    ]
}























