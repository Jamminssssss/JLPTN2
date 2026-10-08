import Foundation

/// CSV fields may contain commas, line breaks, and escaped double quotes.
enum QuizCSVParser {
    static func rows(from content: String) -> [[String]] {
        let characters = Array(content)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false
        var index = characters.first == "\u{FEFF}" ? 1 : 0

        func finishRow() {
            row.append(field)
            if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                rows.append(row)
            }
            row = []
            field = ""
        }

        while index < characters.count {
            let character = characters[index]
            if insideQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"", field.isEmpty {
                insideQuotes = true
            } else if character == "," {
                row.append(field)
                field = ""
            } else if character == "\n" || character == "\r" || character == "\r\n" {
                finishRow()
                if character == "\r", index + 1 < characters.count, characters[index + 1] == "\n" {
                    index += 1
                }
            } else {
                field.append(character)
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty { finishRow() }
        return rows
    }
}
