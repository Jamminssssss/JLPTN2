import Foundation
import AVFoundation

// Compile with the quiz models/loaders and run in a temporary macOS bundle
// containing N2TestApp/Resources/*.csv under Contents/Resources.
@main
struct QuizContentChecks {
    static func main() throws {
        let quoted = "\u{FEFF}a,b,c\r\n\"comma, here\",\"He said \"\"yes\"\"\",\"line 1\nline 2\"\r\nlast,,\r\n"
        precondition(QuizCSVParser.rows(from: quoted) == [
            ["a", "b", "c"],
            ["comma, here", "He said \"yes\"", "line 1\nline 2"],
            ["last", "", ""]
        ], "CSV parser must preserve commas, quotes, multiline fields, and trailing empty columns")

        let expectedReading = [17, 65, 71, 75, 75]
        let expectedListening = [4, 32, 32, 32, 32]
        let audioDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        var audioDurations: [String: TimeInterval] = [:]
        for set in 1...5 {
            for name in ["jlptn2_reading_set\(set)", "jlptn2_audio_set\(set)"] {
                let url = Bundle.main.url(forResource: name, withExtension: "csv")!
                let rows = QuizCSVParser.rows(from: try String(contentsOf: url, encoding: .utf8))
                let header = rows[0]
                for row in rows.dropFirst() {
                    precondition(row.count == header.count, "\(name): shifted columns")
                    precondition(!row[5].isEmpty && row[1...4].contains(row[5]), "\(name): invalid answer")
                    let start = name.contains("reading") ? 8 : 11
                    precondition(row[start..<(start + 10)].allSatisfy { !$0.isEmpty }, "\(name): missing localized explanation/script")
                    if name.contains("reading") {
                        precondition(row[1...4].allSatisfy { !$0.isEmpty }, "\(name): missing reading option")
                        precondition(row[8].range(of: "[가-힣]", options: .regularExpression) != nil,
                                     "\(name): Korean explanation must contain Korean")
                    } else if !row[7].isEmpty || !row[8].isEmpty {
                        guard let startTime = Double(row[7]), let endTime = Double(row[8]),
                              startTime.isFinite, endTime.isFinite, startTime >= 0, endTime > startTime else {
                            preconditionFailure("\(name): invalid playback interval")
                        }
                    }
                    if header.count == 20 {
                        precondition(row[18].isEmpty || row[18].range(of: "^P[0-9]+$", options: .regularExpression) != nil,
                                     "\(name): translation in passage_group")
                    }
                }
            }

            let reading = DataLoader.load(set: set)
            let listening = AudioDataLoader.load(set: set)
            precondition(reading.count == expectedReading[set - 1], "Reading loader dropped or added questions")
            precondition(listening.count == expectedListening[set - 1], "Listening loader dropped valid three-option questions")
            precondition(reading.allSatisfy { $0.options.contains($0.answer) })
            precondition(listening.allSatisfy { $0.options.contains($0.answer) })
            for question in listening {
                if audioDurations[question.audioFileName] == nil {
                    let player = try AVAudioPlayer(contentsOf: audioDirectory.appendingPathComponent(question.audioFileName))
                    audioDurations[question.audioFileName] = player.duration
                }
                if let endTime = question.endTime {
                    precondition(endTime <= audioDurations[question.audioFileName]!,
                                 "\(question.audioFileName): playback extends beyond the audio file")
                }
            }
            let groups = AudioQuestionGroup.group(listening)
            precondition(groups.flatMap(\.questionIndices) == Array(listening.indices))
        }

        let reading3 = DataLoader.load(set: 3)
        precondition(reading3[64].options.count == 4)
        precondition(reading3[64].answer == reading3[64].options[0])
        precondition(reading3[64].passageGroup == "P11")
        precondition(reading3[64].explanationEn?.contains("The writer introduces") == true)

        let reading4 = DataLoader.load(set: 4)
        precondition(reading4[28].explanationKo == "〜を節約する는 비용, 종이, 전기와 같은 자원을 아낄 때 적합합니다.")
        precondition(reading4[28].explanationEn == "〜を節約する fits tangible resources like costs, paper, electricity.")
        precondition(reading4[28].passageGroup == "P6")
        precondition(reading4[44].explanationEn?.contains("Therefore, 1 goes") == true)
        precondition(reading4[73].explanationJa?.contains("7/29, 8/5") == true)

        let listening3 = AudioDataLoader.load(set: 3)
        precondition(listening3[10].answer == listening3[10].options[1])
        precondition(listening3[10].scripts?["ja"]?.contains("商品を販売する店の数を増やした") == true)
        precondition(reading3[32].answer == "についで")
        precondition(reading3[45].answer == "まず")
        precondition(reading4[38].answer == "ならないかな")
        precondition(reading4[50].answer == "というわけだ")
        precondition(reading4[65].answer == reading4[65].options[1])
        let listening4 = AudioDataLoader.load(set: 4)
        precondition(listening4[14].answer == listening4[14].options[1])
        precondition(listening4[22].scripts?["ja"]?.contains("エアコン") == true)
        precondition(listening4[23].scripts?["ja"]?.contains("吉田") == true)
        precondition(listening4[27].scripts?["ja"]?.contains("加藤") == true)
        precondition(listening4[31].scripts?["ja"]?.contains("女の人は") == true)
        for questions in [listening3, listening4, AudioDataLoader.load(set: 5)] {
            precondition(questions[30].startTime == questions[31].startTime)
            precondition(questions[30].endTime == questions[31].endTime)
        }

        // Malformed future records must not be interpreted as valid questions.
        precondition(Bundle.main.url(forResource: "invalid-reading", withExtension: "csv") != nil)
        precondition(Bundle.main.url(forResource: "invalid-audio", withExtension: "csv") != nil)
        precondition(DataLoader.loadFromCSV(fileName: "invalid-reading").isEmpty)
        precondition(AudioDataLoader.loadFromCSV(fileName: "invalid-audio").isEmpty)

        print("PASS: CSV edge cases, all 435 quiz records, loader counts, repaired explanations/answers/scripts, audio asset durations and intervals, invalid-record rejection")
    }
}
