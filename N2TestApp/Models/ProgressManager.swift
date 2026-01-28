import Foundation
import SQLite3
import EventKit
import UIKit

class ProgressManager {
    static let shared = ProgressManager()
    private var db: OpaquePointer?
    private let eventStore = EKEventStore()
    private let calendarIdentifier = "Jlpt N5 Learning"
    private var calendar: EKCalendar?
    
    private init() {
        setupDatabase()
        requestCalendarAccess()
    }
    
    @available(iOS 17.0, *)
    private func requestCalendarAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            if granted {
                DispatchQueue.main.async {
                    self?.setupCalendar()
                }
            } else if let error = error {
                print("Calendar access error: \(error.localizedDescription)")
            }
        }
    }

    
    private func setupCalendar() {
        // 기존 캘린더 찾기
        let calendars = eventStore.calendars(for: .event)
        calendar = calendars.first { $0.title == calendarIdentifier }
        
        // 캘린더가 없으면 새로 생성
        if calendar == nil {
            let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
            newCalendar.title = calendarIdentifier
            newCalendar.cgColor = UIColor.systemBlue.cgColor
            
            // 사용 가능한 캘린더 소스 찾기
            let sources = eventStore.sources
            if let iCloudSource = sources.first(where: { $0.sourceType == .calDAV && $0.title == "iCloud" }) {
                newCalendar.source = iCloudSource
            } else if let localSource = sources.first(where: { $0.sourceType == .local }) {
                newCalendar.source = localSource
            } else if let defaultSource = sources.first {
                newCalendar.source = defaultSource
            }
            
            if newCalendar.source == nil {
                print("No available calendar source found")
                return
            }
            
            do {
                try eventStore.saveCalendar(newCalendar, commit: true)
                calendar = newCalendar
                print("Calendar created successfully with source: \(newCalendar.source?.title ?? "unknown")")
            } catch {
                print("Error creating calendar: \(error.localizedDescription)")
            }
        } else {
            print("Existing calendar found: \(calendar?.title ?? "unknown")")
        }
    }
    
    private func setupDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("progress.sqlite")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
            return
        }
        
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS WordProgress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            wordIndex INTEGER,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS GrammarProgress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            grammarIndex INTEGER,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        -- Daily progress views for each mode
        CREATE VIEW IF NOT EXISTS DailyWordProgress AS
        SELECT 
            date(timestamp) as date,
            COUNT(*) as words_learned,
            MAX(wordIndex) as last_word_index
        FROM WordProgress
        GROUP BY date(timestamp);

        CREATE VIEW IF NOT EXISTS DailyGrammarProgress AS
        SELECT 
            date(timestamp) as date,
            COUNT(*) as grammar_learned,
            MAX(grammarIndex) as last_grammar_index
        FROM GrammarProgress
        GROUP BY date(timestamp);

        -- Overall progress views for each mode
        CREATE VIEW IF NOT EXISTS OverallWordProgress AS
        SELECT 
            COUNT(DISTINCT wordIndex) as total_words_learned,
            (COUNT(DISTINCT wordIndex) * 100.0 / (SELECT COUNT(*) FROM words)) as completion_percentage,
            MAX(wordIndex) as last_word_index
        FROM WordProgress;

        CREATE VIEW IF NOT EXISTS OverallGrammarProgress AS
        SELECT 
            COUNT(DISTINCT grammarIndex) as total_grammar_learned,
            (COUNT(DISTINCT grammarIndex) * 100.0 / (SELECT COUNT(*) FROM grammar)) as completion_percentage,
            MAX(grammarIndex) as last_grammar_index
        FROM GrammarProgress;
        """
        
        if sqlite3_exec(db, createTableQuery, nil, nil, nil) != SQLITE_OK {
            print("Error creating tables")
            return
        }
    }
    
    func saveWordProgress(wordIndex: Int) {
        let insertQuery = "INSERT INTO WordProgress (wordIndex) VALUES (?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(wordIndex))
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error inserting word progress")
            }
        }
        
        sqlite3_finalize(statement)
        
        DispatchQueue.main.async { [weak self] in
            self?.addCalendarEvent(wordIndex: wordIndex, mode: "word")
        }
    }
    
    func saveGrammarProgress(grammarIndex: Int) {
        let insertQuery = "INSERT INTO GrammarProgress (grammarIndex) VALUES (?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(grammarIndex))
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error inserting grammar progress")
            }
        }
        
        sqlite3_finalize(statement)
        
        DispatchQueue.main.async { [weak self] in
            self?.addCalendarEvent(wordIndex: grammarIndex, mode: "grammar")
        }
    }
    
    private func addCalendarEvent(wordIndex: Int, mode: String) {
        guard let calendar = calendar else {
            print("Calendar not available")
            return
        }
        
        // 오늘 날짜의 모든 이벤트를 찾아서 삭제
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = eventStore.predicateForEvents(withStart: today, end: tomorrow, calendars: [calendar])
        let existingEvents = eventStore.events(matching: predicate).filter {
            $0.title.contains("Topik 1 \(mode == "word" ? "단어" : "문법") 학습")
        }
        
        // 기존 이벤트 삭제
        for event in existingEvents {
            do {
                try eventStore.remove(event, span: .thisEvent, commit: false)
            } catch {
                print("Error removing existing event: \(error.localizedDescription)")
            }
        }
        
        // 새 이벤트 생성
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(3600)
        event.title = "Topik 1 \(mode == "word" ? "단어" : "문법") 학습 기록"
        event.notes = "인덱스: \(wordIndex + 1)"
        
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            print("New event saved successfully to calendar: \(calendar.title)")
        } catch {
            print("Error saving new event: \(error.localizedDescription)")
        }
    }
    
    func getLastWordProgress() -> Int? {
        let query = "SELECT wordIndex FROM WordProgress ORDER BY id DESC LIMIT 1;"
        var statement: OpaquePointer?
        var result: Int?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                result = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return result
    }
    
    func getLastGrammarProgress() -> Int? {
        let query = "SELECT grammarIndex FROM GrammarProgress ORDER BY id DESC LIMIT 1;"
        var statement: OpaquePointer?
        var result: Int?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                result = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return result
    }
    
    func clearWordProgress() {
        let deleteQuery = "DELETE FROM WordProgress;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error clearing word progress")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func clearGrammarProgress() {
        let deleteQuery = "DELETE FROM GrammarProgress;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error clearing grammar progress")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func getDailyWordProgress() -> [(date: String, wordsLearned: Int, lastWordIndex: Int)] {
        var result: [(date: String, wordsLearned: Int, lastWordIndex: Int)] = []
        let query = "SELECT date, words_learned, last_word_index FROM DailyWordProgress ORDER BY date DESC"
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let date = String(cString: sqlite3_column_text(statement, 0))
                let wordsLearned = Int(sqlite3_column_int(statement, 1))
                let lastWordIndex = Int(sqlite3_column_int(statement, 2))
                result.append((date: date, wordsLearned: wordsLearned, lastWordIndex: lastWordIndex))
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    func getDailyGrammarProgress() -> [(date: String, grammarLearned: Int, lastGrammarIndex: Int)] {
        var result: [(date: String, grammarLearned: Int, lastGrammarIndex: Int)] = []
        let query = "SELECT date, grammar_learned, last_grammar_index FROM DailyGrammarProgress ORDER BY date DESC"
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let date = String(cString: sqlite3_column_text(statement, 0))
                let grammarLearned = Int(sqlite3_column_int(statement, 1))
                let lastGrammarIndex = Int(sqlite3_column_int(statement, 2))
                result.append((date: date, grammarLearned: grammarLearned, lastGrammarIndex: lastGrammarIndex))
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    func getOverallWordProgress() -> (totalWordsLearned: Int, completionPercentage: Double, lastWordIndex: Int)? {
        let query = "SELECT total_words_learned, completion_percentage, last_word_index FROM OverallWordProgress"
        
        var statement: OpaquePointer?
        var result: (totalWordsLearned: Int, completionPercentage: Double, lastWordIndex: Int)?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let totalWordsLearned = Int(sqlite3_column_int(statement, 0))
                let completionPercentage = sqlite3_column_double(statement, 1)
                let lastWordIndex = Int(sqlite3_column_int(statement, 2))
                result = (totalWordsLearned: totalWordsLearned, completionPercentage: completionPercentage, lastWordIndex: lastWordIndex)
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    func getOverallGrammarProgress() -> (totalGrammarLearned: Int, completionPercentage: Double, lastGrammarIndex: Int)? {
        let query = "SELECT total_grammar_learned, completion_percentage, last_grammar_index FROM OverallGrammarProgress"
        
        var statement: OpaquePointer?
        var result: (totalGrammarLearned: Int, completionPercentage: Double, lastGrammarIndex: Int)?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                let totalGrammarLearned = Int(sqlite3_column_int(statement, 0))
                let completionPercentage = sqlite3_column_double(statement, 1)
                let lastGrammarIndex = Int(sqlite3_column_int(statement, 2))
                result = (totalGrammarLearned: totalGrammarLearned, completionPercentage: completionPercentage, lastGrammarIndex: lastGrammarIndex)
            }
        }
        sqlite3_finalize(statement)
        return result
    }
    
    deinit {
        sqlite3_close(db)
    }
}
