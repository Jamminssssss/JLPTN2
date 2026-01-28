import Foundation
import SwiftUI

let words: [Word] = [
    Word(kanji: "明け方",
         reading: "あけがた",
         meanings: [
            "ko": "새벽; 동틀녘",
            "en": "dawn",
            "ja": "明け方",
            "zh-Hans": "黎明; 拂晓",
            "vi": "bình minh; rạng đông",
            "th": "รุ่งอรุณ; เช้ามืด"
         ]),
    Word(kanji: "青白い",
         reading: "あおじろい",
         meanings: [
            "ko": "창백한; 푸르스름한",
            "en": "pale; bluish-white",
            "ja": "青白い",
            "zh-Hans": "苍白的; 青白色的",
            "vi": "tái nhợt; xanh xao",
            "th": "ซีด; ขาวอมฟ้า"
         ]),
    Word(kanji: "足跡",
         reading: "あしあと",
         meanings: [
            "ko": "발자국",
            "en": "footprints",
            "ja": "足跡",
            "zh-Hans": "脚印; 足迹",
            "vi": "dấu chân",
            "th": "รอยเท้า"
         ]),
    Word(kanji: "売買",
         reading: "ばいばい",
         meanings: [
            "ko": "매매; 사고팔기",
            "en": "trade; buying and selling",
            "ja": "売買",
            "zh-Hans": "买卖; 交易",
            "vi": "mua bán; giao dịch",
            "th": "การซื้อขาย; การค้า"
         ]),
    Word(kanji: "売店",
         reading: "ばいてん",
         meanings: [
            "ko": "매점; 가판대",
            "en": "stand; stall; booth; kiosk; store",
            "ja": "売店",
            "zh-Hans": "小卖部; 售货亭",
            "vi": "quầy hàng; sạp hàng; ki-ốt",
            "th": "ร้านค้าเล็กๆ; แผงลอย; คีออสก์"
         ]),
    Word(kanji: "募集",
         reading: "ぼしゅう",
         meanings: [
            "ko": "모집; 초빙",
            "en": "recruitment; invitation; taking applications; solicitation",
            "ja": "募集",
            "zh-Hans": "招募; 征集",
            "vi": "tuyển dụng; mời; chiêu mộ",
            "th": "การรับสมัคร; การเชิญชวน"
         ]),
    Word(kanji: "長男",
         reading: "ちょうなん",
         meanings: [
            "ko": "장남; 맏아들",
            "en": "eldest son; first-born son",
            "ja": "長男",
            "zh-Hans": "长子; 大儿子",
            "vi": "con trai cả; trưởng nam",
            "th": "ลูกชายคนโต"
         ]),
    Word(kanji: "楕円",
         reading: "だえん",
         meanings: [
            "ko": "타원",
            "en": "ellipse",
            "ja": "楕円",
            "zh-Hans": "椭圆",
            "vi": "hình elip",
            "th": "วงรี"
         ]),
    Word(kanji: "大学院",
         reading: "だいがくいん",
         meanings: [
            "ko": "대학원",
            "en": "graduate school",
            "ja": "大学院",
            "zh-Hans": "研究生院",
            "vi": "trường cao học; viện sau đại học",
            "th": "บัณฑิตวิทยาลัย"
         ]),
    Word(kanji: "出入口",
         reading: "でいりぐち",
         meanings: [
            "ko": "출입구",
            "en": "exit and entrance",
            "ja": "出入口",
            "zh-Hans": "出入口",
            "vi": "lối ra vào",
            "th": "ทางเข้าออก"
         ]),
    Word(kanji: "宴会",
         reading: "えんかい",
         meanings: [
            "ko": "연회; 잔치",
            "en": "party; banquet; reception; feast; dinner",
            "ja": "宴会",
            "zh-Hans": "宴会; 酒席",
            "vi": "tiệc; yến tiệc",
            "th": "งานเลี้ยง; งานสังสรรค์"
         ]),
    Word(kanji: "円周",
         reading: "えんしゅう",
         meanings: [
            "ko": "원주; 둘레",
            "en": "circumference",
            "ja": "円周",
            "zh-Hans": "圆周",
            "vi": "chu vi hình tròn",
            "th": "เส้นรอบวง"
         ]),
    Word(kanji: "遠足",
         reading: "えんそく",
         meanings: [
            "ko": "소풍; 원족",
            "en": "excursion; outing; trip",
            "ja": "遠足",
            "zh-Hans": "远足;郊游",
            "vi": "chuyến dã ngoại; chuyến đi chơi xa",
            "th": "การทัศนศึกษา; การไปเที่ยวแบบไปเช้าเย็นกลับ"
         ]),
    Word(kanji: "父母",
         reading: "ふぼ",
         meanings: [
            "ko": "부모",
            "en": "father and mother; parents",
            "ja": "父母",
            "zh-Hans": "父母",
            "vi": "cha mẹ; phụ mẫu",
            "th": "พ่อแม่; บิดามารดา"
         ]),
    Word(kanji: "学科",
         reading: "がっか",
         meanings: [
            "ko": "학과; 전공과목",
            "en": "study subject; course of study; department",
            "ja": "学科",
            "zh-Hans": "学科; 专业; 系",
            "vi": "môn học; ngành học; khoa",
            "th": "สาขาวิชา; ภาควิชา"
         ]),
    Word(kanji: "学会",
         reading: "がっかい",
         meanings: [
            "ko": "학회; 학술 대회",
            "en": "scientific society; academic meeting; academic conference",
            "ja": "学会",
            "zh-Hans": "学会;学术会议",
            "vi": "hội khoa học; hội nghị học thuật",
            "th": "สมาคมวิชาการ; การประชุมทางวิชาการ"
         ]),
    Word(kanji: "学力",
         reading: "がくりょく",
         meanings: [
            "ko": "학력; 학문적 능력",
            "en": "scholarly ability; scholarship; knowledge; literary ability",
            "ja": "学力",
            "zh-Hans": "学力; 学识",
            "vi": "học lực; trình độ học vấn",
            "th": "ความสามารถทางวิชาการ; ความรู้"
         ]),
    Word(kanji: "外科",
         reading: "げか",
         meanings: [
            "ko": "외과; 외과 부서",
            "en": "surgery; department of surgery",
            "ja": "外科",
            "zh-Hans": "外科; 外科部门",
            "vi": "ngoại khoa; khoa ngoại",
            "th": "ศัลยกรรม; แผนกศัลยกรรม"
         ]),
    Word(kanji: "花火",
         reading: "はなび",
         meanings: [
            "ko": "불꽃놀이; 불꽃",
            "en": "fireworks",
            "ja": "花火",
            "zh-Hans": "烟花; 焰火",
            "vi": "pháo hoa",
            "th": "ดอกไม้ไฟ; พลุ"
         ]),
    Word(kanji: "半径",
         reading: "はんけい",
         meanings: [
            "ko": "반지름; 반경",
            "en": "radius",
            "ja": "半径",
            "zh-Hans": "半径",
            "vi": "bán kính",
            "th": "รัศมี"
         ]),
    Word(kanji: "半島",
         reading: "はんとう",
         meanings: [
            "ko": "반도",
            "en": "peninsula",
            "ja": "半島",
            "zh-Hans": "半岛",
            "vi": "bán đảo",
            "th": "คาบสมุทร"
         ]),
    Word(kanji: "発売",
         reading: "はつばい",
         meanings: [
            "ko": "발매; 출시",
            "en": "sale; release (for sale); launch (product)",
            "ja": "発売",
            "zh-Hans": "发售; 上市",
            "vi": "phát hành; ra mắt (sản phẩm); mở bán",
            "th": "การวางจำหน่าย; การเปิดตัวสินค้า"
         ]),
    Word(kanji: "早口",
         reading: "はやくち",
         meanings: [
            "ko": "말이 빠름; 속사포",
            "en": "fast-talking; rapid talking",
            "ja": "早口",
            "zh-Hans": "说话快; 口齿伶俐",
            "vi": "nói nhanh; nói liến thoắng",
            "th": "การพูดเร็ว"
         ]),
    Word(kanji: "外れる",
         reading: "はずれる",
         meanings: [
            "ko": "벗어나다; 떨어지다; 빗나가다",
            "en": "to be disconnected; to be off; to miss the mark",
            "ja": "外れる",
            "zh-Hans": "脱落; 偏离; 未中",
            "vi": "bị tuột ra; trật; không trúng",
            "th": "หลุด; พลาด; ไม่ตรงเป้า"
         ]),
    Word(kanji: "閉会",
         reading: "へいかい",
         meanings: [
            "ko": "폐회; 마침",
            "en": "closure (of a ceremony, event, meeting, etc.)",
            "ja": "閉会",
            "zh-Hans": "闭会; 结束",
            "vi": "bế mạc (buổi lễ, sự kiện, cuộc họp, v.v.)",
            "th": "การปิด (พิธี, งาน, การประชุม ฯลฯ)"
         ]),
    Word(kanji: "昼寝",
         reading: "ひるね",
         meanings: [
            "ko": "낮잠",
            "en": "nap, siesta",
            "ja": "昼寝",
            "zh-Hans": "午睡; 小睡",
            "vi": "ngủ trưa",
            "th": "การงีบหลับ; นอนกลางวัน"
         ]),
    Word(kanji: "意地悪",
         reading: "いじわる",
         meanings: [
            "ko": "심술궂은; 못된",
            "en": "malicious; ill-tempered; unkind",
            "ja": "意地悪",
            "zh-Hans": "使坏; 心术不正的; 不友善的",
            "vi": "hiểm ác; xấu tính; không tử tế",
            "th": "มุ่งร้าย; นิสัยไม่ดี; ใจร้าย"
         ]),
    Word(kanji: "移転",
         reading: "いてん",
         meanings: [
            "ko": "이전; 이사; 주소 변경",
            "en": "moving; relocation; change of address",
            "ja": "移転",
            "zh-Hans": "搬迁; 迁移; 地址变更",
            "vi": "di chuyển; dời đi; thay đổi địa chỉ",
            "th": "การย้าย; การเปลี่ยนที่อยู่"
         ]),
    Word(kanji: "一旦",
         reading: "いったん",
         meanings: [
            "ko": "일단; 잠시; 일시적으로",
            "en": "once; for a short time; briefly; temporarily",
            "ja": "一旦",
            "zh-Hans": "一旦; 暂时; 短暂地",
            "vi": "một khi; một lát; tạm thời",
            "th": "ครั้น; ชั่วคราว; สักครู่"
         ]),
    Word(kanji: "寺院",
         reading: "じいん",
         meanings: [
            "ko": "사원; 절; 종교 건물",
            "en": "Buddhist temple; religious building",
            "ja": "寺院",
            "zh-Hans": "寺院; 宗教建筑",
            "vi": "chùa; đền thờ; công trình tôn giáo",
            "th": "วัดพุทธ; ศาสนสถาน"
         ]),
    Word(kanji: "人文科学",
         reading: "じんぶんかがく",
         meanings: [
            "ko": "인문과학; 사회과학; 문리과",
            "en": "humanities; social sciences; liberal arts",
            "ja": "人文科学",
            "zh-Hans": "人文学科; 社会科学; 文科",
            "vi": "khoa học nhân văn; khoa học xã hội; nghệ thuật tự do",
            "th": "มนุษยศาสตร์; สังคมศาสตร์; ศิลปศาสตร์"
         ]),
    Word(kanji: "自習",
         reading: "じしゅう",
         meanings: [
            "ko": "자습; 독학",
            "en": "self-study; teaching oneself",
            "ja": "自習",
            "zh-Hans": "自习; 自学",
            "vi": "tự học",
            "th": "การศึกษาด้วยตนเอง"
         ]),
    Word(kanji: "時速",
         reading: "じそく",
         meanings: [
            "ko": "시속",
            "en": "speed (per hour)",
            "ja": "時速",
            "zh-Hans": "时速",
            "vi": "tốc độ (mỗi giờ)",
            "th": "ความเร็ว (ต่อชั่วโมง)"
         ]),
    Word(kanji: "実習",
         reading: "じっしゅう",
         meanings: [
            "ko": "실습; 훈련; 연습",
            "en": "practice; training; practical exercise; drill",
            "ja": "実習",
            "zh-Hans": "实习; 实践; 演练",
            "vi": "thực hành; thực tập; rèn luyện",
            "th": "การฝึกงาน; การฝึกปฏิบัติ; การฝึกซ้อม"
         ]),
    Word(kanji: "過半数",
         reading: "かはんすう",
         meanings: [
            "ko": "과반수; 대다수",
            "en": "majority",
            "ja": "過半数",
            "zh-Hans": "过半数; 大多数",
            "vi": "đa số; quá bán",
            "th": "เสียงข้างมาก; ส่วนใหญ่"
         ]),
    Word(kanji: "開会",
         reading: "かいかい",
         meanings: [
            "ko": "개회; 시작",
            "en": "opening of a meeting; starting (an event, etc)",
            "ja": "開会",
            "zh-Hans": "开会; 开始",
            "vi": "khai mạc (cuộc họp); bắt đầu (sự kiện, v.v.)",
            "th": "การเปิดประชุม; การเริ่มต้น (งาน ฯลฯ)"
         ]),
    Word(kanji: "会館",
         reading: "かいかん",
         meanings: [
            "ko": "회관; 집회소",
            "en": "meeting hall; assembly hall",
            "ja": "会館",
            "zh-Hans": "会馆; 集会堂",
            "vi": "hội quán; phòng họp lớn",
            "th": "หอประชุม"
         ]),
    Word(kanji: "回転",
         reading: "かいてん",
         meanings: [
            "ko": "회전; 선회",
            "en": "rotation; revolution; turning",
            "ja": "回転",
            "zh-Hans": "旋转; 转动",
            "vi": "sự quay; vòng quay; sự xoay",
            "th": "การหมุน; การหมุนรอบ"
         ]),
    Word(kanji: "加速",
         reading: "かそく",
         meanings: [
            "ko": "가속; 속도를 높임",
            "en": "acceleration; speeding up",
            "ja": "加速",
            "zh-Hans": "加速; 加快速度",
            "vi": "gia tốc; tăng tốc",
            "th": "ความเร่ง; การเพิ่มความเร็ว"
         ]),
    Word(kanji: "加速度",
         reading: "かそくど",
         meanings: [
            "ko": "가속도",
            "en": "acceleration",
            "ja": "加速度",
            "zh-Hans": "加速度",
            "vi": "gia tốc",
            "th": "ความเร่ง"
         ]),
    Word(kanji: "見学",
         reading: "けんがく",
         meanings: [
            "ko": "견학; 현장 학습; 시찰",
            "en": "study by observation; field trip; tour; review; inspection",
            "ja": "見学",
            "zh-Hans": "参观学习; 实地考察; 游览; 审查; 检查",
            "vi": "tham quan học tập; đi thực tế; chuyến tham quan",
            "th": "การทัศนศึกษา; การเยี่ยมชมเพื่อศึกษา; การตรวจสอบ"
         ]),
    Word(kanji: "国王",
         reading: "こくおう",
         meanings: [
            "ko": "국왕; 여왕; 군주",
            "en": "king; queen; monarch; sovereign",
            "ja": "国王",
            "zh-Hans": "国王; 女王; 君主; 元首",
            "vi": "vua; nữ hoàng; quốc vương",
            "th": "กษัตริย์; ราชินี; ประมุข"
         ]),
    Word(kanji: "国立",
         reading: "こくりつ",
         meanings: [
            "ko": "국립",
            "en": "national",
            "ja": "国立",
            "zh-Hans": "国立的",
            "vi": "quốc gia; quốc lập",
            "th": "แห่งชาติ; ของรัฐ"
         ]),
    Word(kanji: "国籍",
         reading: "こくせき",
         meanings: [
            "ko": "국적; 시민권",
            "en": "nationality; citizenship",
            "ja": "国籍",
            "zh-Hans": "国籍; 公民身份",
            "vi": "quốc tịch",
            "th": "สัญชาติ"
         ]),
    Word(kanji: "転がる",
         reading: "ころがる",
         meanings: [
            "ko": "구르다; 넘어지다; 드러눕다",
            "en": "to roll; to fall over; to lie down",
            "ja": "転がる",
            "zh-Hans": "滚动; 跌倒; 躺下",
            "vi": "lăn; ngã; nằm xuống",
            "th": "กลิ้ง; ล้ม; นอนลง"
         ]),
    Word(kanji: "転がす",
         reading: "ころがす",
         meanings: [
            "ko": "굴리다; 뒤집다",
            "en": "to roll; to turn over",
            "ja": "転がす",
            "zh-Hans": "使滚动; 翻转",
            "vi": "lăn (một vật gì đó); lật",
            "th": "ทำให้กลิ้ง; พลิก"
         ]),
    Word(kanji: "校舎",
         reading: "こうしゃ",
         meanings: [
            "ko": "교사; 학교 건물",
            "en": "school building; schoolhouse",
            "ja": "校舎",
            "zh-Hans": "校舍; 教学楼",
            "vi": "tòa nhà trường học",
            "th": "อาคารเรียน"
         ]),
    Word(kanji: "校庭",
         reading: "こうてい",
         meanings: [
            "ko": "교정; 운동장; 학교 마당",
            "en": "schoolyard; playground; school grounds; campus",
            "ja": "校庭",
            "zh-Hans": "校园;操场; 校内场地",
            "vi": "sân trường; sân chơi; khuôn viên trường",
            "th": "สนามโรงเรียน; บริเวณโรงเรียน"
         ]),
    Word(kanji: "待合室",
         reading: "まちあいしつ",
         meanings: [
            "ko": "대합실; 기다리는 곳",
            "en": "waiting room",
            "ja": "待合室",
            "zh-Hans": "候诊室; 等候室",
            "vi": "phòng chờ",
            "th": "ห้องพักรอ"
         ]),
    Word(kanji: "待ち合わせる",
         reading: "まちあわせる",
         meanings: [
            "ko": "만나기로 약속하다; 약속하여 만나다",
            "en": "to rendezvous; to meet at a prearranged place and time; to arrange to meet",
            "ja": "待ち合わせる",
            "zh-Hans": "约会; (在预定地点和时间)会面; 安排见面",
            "vi": "hẹn gặp; gặp nhau tại địa điểm và thời gian đã định trước",
            "th": "นัดพบ; พบกันตามที่นัดหมาย"
         ]),
    Word(kanji: "窓口",
         reading: "まどぐち",
         meanings: [
            "ko": "창구; 매표소",
            "en": "ticket window; teller window; counter",
            "ja": "窓口",
            "zh-Hans": "售票窗口; 柜台",
            "vi": "quầy vé; quầy giao dịch",
            "th": "ช่องขายตั๋ว; เคาน์เตอร์บริการ"
         ]),
    Word(kanji: "毎度",
         reading: "まいど",
         meanings: [
            "ko": "매번; 늘; 자주; 항상 감사합니다 (단골손님에게)",
            "en": "each time; always; often; thank you for your continued patronage​",
            "ja": "毎度",
            "zh-Hans": "每次; 总是; 经常; 承蒙惠顾",
            "vi": "mỗi lần; luôn luôn; thường xuyên; cảm ơn quý khách đã luôn ủng hộ",
            "th": "ทุกครั้ง; เสมอ; บ่อยๆ; ขอบคุณที่อุดหนุนเสมอ"
         ]),
    Word(kanji: "真っ青",
         reading: "まっさお",
         meanings: [
            "ko": "새파란; 창백한",
            "en": "deep blue; bright blue​; ghastly pale; white as a sheet",
            "ja": "真っ青",
            "zh-Hans": "深蓝色; 鲜蓝色; 惨白; 脸色苍白",
            "vi": "xanh đậm; xanh biếc; tái mét; trắng bệch",
            "th": "สีน้ำเงินเข้ม; สีฟ้าสด; ซีดเผือด"
         ]),
    Word(kanji: "真っ白",
         reading: "まっしろ",
         meanings: [
            "ko": "새하얀; 순백의; 공백의",
            "en": "pure white; blank",
            "ja": "真っ白",
            "zh-Hans": "纯白色; 空白",
            "vi": "trắng tinh; trống trơn",
            "th": "ขาวบริสุทธิ์; ว่างเปล่า"
         ]),
    Word(kanji: "名刺",
         reading: "めいし",
         meanings: [
            "ko": "명함",
            "en": "business card",
            "ja": "名刺",
            "zh-Hans": "名片",
            "vi": "danh thiếp",
            "th": "นามบัตร"
         ]),
    Word(kanji: "店屋",
         reading: "みせや",
         meanings: [
            "ko": "가게; 상점",
            "en": "store; shop",
            "ja": "店屋",
            "zh-Hans": "商店; 店铺",
            "vi": "cửa hàng; cửa hiệu",
            "th": "ร้านค้า"
         ]),
    Word(kanji: "木材",
         reading: "もくざい",
         meanings: [
            "ko": "목재; 재목",
            "en": "lumber; timber; wood",
            "ja": "木材",
            "zh-Hans": "木材; 木料",
            "vi": "gỗ; gỗ xây dựng",
            "th": "ไม้แปรรูป; ไม้ซุง"
         ]),
    Word(kanji: "元々",
         reading: "もともと",
         meanings: [
            "ko": "원래; 본래; 처음부터",
            "en": "originally, by nature, from the start",
            "ja": "元々",
            "zh-Hans": "原本; 本来; 从一开始",
            "vi": "vốn dĩ; ban đầu; từ đầu",
            "th": "แต่เดิม; โดยธรรมชาติ; ตั้งแต่แรก"
         ]),
    Word(kanji: "内科",
         reading: "ないか",
         meanings: [
            "ko": "내과",
            "en": "internal medicine",
            "ja": "内科",
            "zh-Hans": "内科",
            "vi": "nội khoa",
            "th": "อายุรศาสตร์; แผนกอายุรกรรม"
         ]),
    Word(kanji: "並木",
         reading: "なみき",
         meanings: [
            "ko": "가로수; 나란히 선 나무들",
            "en": "roadside tree; row of trees",
            "ja": "並木",
            "zh-Hans": "林荫树; 行道树",
            "vi": "cây ven đường; hàng cây",
            "th": "ต้นไม้ริมทาง; แนวต้นไม้"
         ]),
    Word(kanji: "入社",
         reading: "にゅうしゃ",
         meanings: [
            "ko": "입사; 회사에 들어감",
            "en": "joining a company",
            "ja": "入社",
            "zh-Hans": "入职; 进入公司",
            "vi": "vào công ty làm việc; gia nhập công ty",
            "th": "การเข้าทำงานในบริษัท"
         ]),
    Word(kanji: "押さえる",
         reading: "おさえる",
         meanings: [
            "ko": "누르다; 억누르다; 잡다",
            "en": "to pin down; to hold down; to press down",
            "ja": "押さえる",
            "zh-Hans": "按住; 压住; 抑制",
            "vi": "giữ chặt; đè xuống; ấn xuống",
            "th": "กดไว้; จับไว้; ควบคุมไว้"
         ]),
    Word(kanji: "理科",
         reading: "りか",
         meanings: [
            "ko": "이과; 과학 (학과; 과목)",
            "en": "science (department; course)",
            "ja": "理科",
            "zh-Hans": "理科 (系; 课程)",
            "vi": "khoa học tự nhiên (khoa; môn học)",
            "th": "วิทยาศาสตร์ (ภาควิชา; รายวิชา)"
         ]),
    Word(kanji: "領収",
         reading: "りょうしゅう",
         meanings: [
            "ko": "영수; 받음 (돈)",
            "en": "receipt (of money); receiving",
            "ja": "領収",
            "zh-Hans": "收据; 收到 (钱款)",
            "vi": "biên lai (nhận tiền); sự nhận",
            "th": "ใบเสร็จรับเงิน; การรับ (เงิน)"
         ]),
    Word(kanji: "再三",
         reading: "さいさん",
         meanings: [
            "ko": "재삼; 여러 번; 거듭",
            "en": "again and again; repeatedly",
            "ja": "再三",
            "zh-Hans": "再三; 一再",
            "vi": "nhiều lần; lặp đi lặp lại",
            "th": "ครั้งแล้วครั้งเล่า; ซ้ำๆ"
         ]),
    Word(kanji: "刺さる",
         reading: "ささる",
         meanings: [
            "ko": "박히다; 찔리다; 걸리다",
            "en": "to stick into (with a sharp point); to prick; to get stuck (in)",
            "ja": "刺さる",
            "zh-Hans": "刺入; 扎进; 卡住",
            "vi": "cắm vào; đâm vào; bị mắc kẹt",
            "th": "ทิ่มแทง; ปัก; ติดอยู่"
         ]),
    Word(kanji: "刺身",
         reading: "さしみ",
         meanings: [
            "ko": "사시미; 생선회",
            "en": "sashimi (raw sliced fish, shellfish or crustaceans)",
            "ja": "刺身",
            "zh-Hans": "生鱼片",
            "vi": "sashimi (cá, hải sản sống thái lát)",
            "th": "ซาชิมิ (ปลาดิบหั่นชิ้น)"
         ]),
    Word(kanji: "早速",
         reading: "さっそく",
         meanings: [
            "ko": "즉시; 곧바로; 지체 없이",
            "en": "at once; immediately; without delay; promptly",
            "ja": "早速",
            "zh-Hans": "立刻; 马上; 毫不迟延地",
            "vi": "ngay lập tức; ngay; không chậm trễ",
            "th": "ทันที; โดยเร็ว; ไม่ชักช้า"
         ]),
    Word(kanji: "刺す",
         reading: "さす",
         meanings: [
            "ko": "찌르다; 쏘다",
            "en": "to pierce; to stab; to prick; to stick; to thrust; to sting",
            "ja": "刺す",
            "zh-Hans": "刺; 戳; 扎; 叮",
            "vi": "đâm; chích; chọc; cắm; đốt (côn trùng)",
            "th": "แทง; ทิ่ม; ต่อย (แมลง)"
         ]),
    Word(kanji: "青少年",
         reading: "せいしょうねん",
         meanings: [
            "ko": "청소년; 젊은이",
            "en": "youth; young person",
            "ja": "青少年",
            "zh-Hans": "青少年; 年轻人",
            "vi": "thanh thiếu niên; người trẻ tuổi",
            "th": "เยาวชน; คนหนุ่มสาว"
         ]),
    Word(kanji: "赤道",
         reading: "せきどう",
         meanings: [
            "ko": "적도",
            "en": "equator",
            "ja": "赤道",
            "zh-Hans": "赤道",
            "vi": "xích đạo",
            "th": "เส้นศูนย์สูตร"
         ]),
    Word(kanji: "社会科学",
         reading: "しゃかいかがく",
         meanings: [
            "ko": "사회과학",
            "en": "social science",
            "ja": "社会科学",
            "zh-Hans": "社会科学",
            "vi": "khoa học xã hội",
            "th": "สังคมศาสตร์"
         ]),
    Word(kanji: "社説",
         reading: "しゃせつ",
         meanings: [
            "ko": "사설; 주요 기사",
            "en": "editorial; leading article; leader",
            "ja": "社説",
            "zh-Hans": "社论; 重要文章",
            "vi": "xã luận; bài xã luận",
            "th": "บทบรรณาธิการ"
         ]),
    Word(kanji: "司会",
         reading: "しかい",
         meanings: [
            "ko": "사회; 사회자; 진행자",
            "en": "master of ceremonies; leading a meeting; presenter; host",
            "ja": "司会",
            "zh-Hans": "主持人; 主持会议; 司仪",
            "vi": "người dẫn chương trình; chủ trì cuộc họp; người giới thiệu",
            "th": "พิธีกร; ผู้ดำเนินรายการ; ผู้ควบคุมการประชุม"
         ]),
    ]
