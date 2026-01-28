//
//  Word.swift
//  JLPT Word N3
//
//  Created by Jeamin on 9/9/24.
//

import SwiftUI
import Foundation

struct Word: Identifiable {
    let id = UUID()
    let kanji: String
    let reading: String
    let meanings: [String: String] // 언어 코드: 의미
    
    var korean: String { meanings["ko"] ?? "" }
    var english: String { meanings["en"] ?? "" }
    var japanese: String { meanings["ja"] ?? "" }
    var chinese: String { meanings["zh-Hans"] ?? "" }
    
    init(kanji: String, reading: String, meanings: [String: String]) {
        self.kanji = kanji
        self.reading = reading
        self.meanings = meanings
    }
    
    func meaning(for language: String) -> String {
        if language == "zh-Hans" {
            return meanings["zh-Hans"] ?? meanings["ko"] ?? "의미 없음"
        }
        return meanings[language] ?? meanings["ko"] ?? "의미 없음"
    }
}
