import SQLite3
import Foundation
import EventKit
import UIKit
import CloudKit // 🌟 필수

struct IncorrectNote: Identifiable, Equatable {
    let id: Int
    let level: String
    let quizGroup: String
    let questionIndex: Int
    let timestamp: Date
    let requiresSubscription: Bool
}

struct ProgressRow {
    let level: String
    let quizGroup: String
    let lastQuestionIndex: Int
}

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private let eventStore = EKEventStore()
    private let calendarIdentifier = "Jlpt Learning"
    private var calendar: EKCalendar?
    var debugMode = false
    
    // 🌟 핵심 해결책: 동시 접근 방지 및 크래시 예방을 위한 직렬 큐
    private let dbQueue = DispatchQueue(label: "com.databasemanager.dbQueue")
    
    private init() {
        openDatabase()
        updateTableSchema()
        createTable()
        createIncorrectNotesTable()
        requestCalendarAccess()
    }
    
    @available(iOS 17.0, *)
    private func requestCalendarAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            if granted { DispatchQueue.main.async { self?.setupCalendar() } }
        }
    }
    
    private func setupCalendar() { /* 기존 로직과 동일 */ }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func openDatabase() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("quiz_progress.sqlite")
        sqlite3_open(fileURL.path, &db)
    }
    
    private func createTable() {
        dbQueue.sync {
            let q = "CREATE TABLE IF NOT EXISTS progress (level TEXT, quizGroup TEXT, lastQuestionIndex INTEGER, PRIMARY KEY (level, quizGroup));"
            sqlite3_exec(db, q, nil, nil, nil)
        }
    }
    
    private func createIncorrectNotesTable() {
        dbQueue.sync {
            let q = "CREATE TABLE IF NOT EXISTS incorrect_notes (level TEXT, quizGroup TEXT, questionIndex INTEGER, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP, requiresSubscription INTEGER DEFAULT 0, PRIMARY KEY (level, quizGroup, questionIndex));"
            sqlite3_exec(db, q, nil, nil, nil)
        }
    }
    
    private func updateTableSchema() { /* 기존 로직과 동일 */ }
    
    func saveProgress(level: String, quizGroup: String, index: Int) {
        saveProgressLocalOnly(level: level, quizGroup: quizGroup, index: index)
        pushProgressToCloudKit(level: level, quizGroup: quizGroup, index: index)
    }
    
    func saveProgressLocalOnly(level: String, quizGroup: String, index: Int) {
        dbQueue.sync {
            sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
            let updateQuery = "UPDATE progress SET lastQuestionIndex = ? WHERE level = ? AND quizGroup = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, updateQuery, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(index))
                sqlite3_bind_text(stmt, 2, (level as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (quizGroup as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            if sqlite3_changes(db) == 0 {
                let insertQuery = "INSERT INTO progress (level, quizGroup, lastQuestionIndex) VALUES (?, ?, ?);"
                if sqlite3_prepare_v2(db, insertQuery, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_text(stmt, 1, (level as NSString).utf8String, -1, nil)
                    sqlite3_bind_text(stmt, 2, (quizGroup as NSString).utf8String, -1, nil)
                    sqlite3_bind_int(stmt, 3, Int32(index))
                    sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            sqlite3_exec(db, "COMMIT", nil, nil, nil)
        }
    }
    
    func pushProgressToCloudKit(level: String, quizGroup: String, index: Int) {
        let fields: [String: CKRecordValue] = ["level": level as CKRecordValue, "quizGroup": quizGroup as CKRecordValue, "lastQuestionIndex": Int64(index) as CKRecordValue]
        CloudKitManager.shared.upload(type: .examProgress, recordName: CloudKitManager.progressRecordName(level: level, quizGroup: quizGroup), fields: fields)
    }
    
    func loadProgress(level: String, quizGroup: String) -> Int {
        var lastIndex = 0
        dbQueue.sync {
            let q = "SELECT lastQuestionIndex FROM progress WHERE level = ? AND quizGroup = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (level as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (quizGroup as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW { lastIndex = Int(sqlite3_column_int(stmt, 0)) }
            }
            sqlite3_finalize(stmt)
        }
        return lastIndex
    }
    
    func resetProgress(level: String, quizGroup: String) {
        dbQueue.sync {
            let q = "DELETE FROM progress WHERE level = ? AND quizGroup = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (level as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (quizGroup as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func saveIncorrectAnswer(level: String, quizGroup: String, questionIndex: Int, requiresSubscription: Bool = false) {
        let timestamp = Date()
        upsertIncorrectNoteLocalOnly(level: level, quizGroup: quizGroup, questionIndex: questionIndex, timestamp: timestamp, requiresSubscription: requiresSubscription)
        pushIncorrectNoteToCloudKit(level: level, quizGroup: quizGroup, questionIndex: questionIndex, timestamp: timestamp, requiresSubscription: requiresSubscription)
        NotificationCenter.default.post(name: Notification.Name("incorrectNotesDidUpdate"), object: nil)
    }
    
    func upsertIncorrectNoteLocalOnly(level: String, quizGroup: String, questionIndex: Int, timestamp: Date, requiresSubscription: Bool) {
        dbQueue.sync {
            let q = "INSERT OR REPLACE INTO incorrect_notes (level, quizGroup, questionIndex, timestamp, requiresSubscription) VALUES (?, ?, ?, ?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (level as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (quizGroup as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 3, Int32(questionIndex))
                let formatter = ISO8601DateFormatter()
                sqlite3_bind_text(stmt, 4, (formatter.string(from: timestamp) as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 5, requiresSubscription ? 1 : 0)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func pushIncorrectNoteToCloudKit(level: String, quizGroup: String, questionIndex: Int, timestamp: Date, requiresSubscription: Bool) {
        let fields: [String: CKRecordValue] = [
            "level": level as CKRecordValue, "quizGroup": quizGroup as CKRecordValue, "questionIndex": Int64(questionIndex) as CKRecordValue,
            "timestamp": timestamp as CKRecordValue, "requiresSubscription": Int64(requiresSubscription ? 1 : 0) as CKRecordValue
        ]
        CloudKitManager.shared.upload(type: .incorrectNote, recordName: CloudKitManager.incorrectNoteRecordName(level: level, quizGroup: quizGroup, questionIndex: questionIndex), fields: fields)
    }
    
    func deleteIncorrectAnswer(level: String, quizGroup: String, questionIndex: Int) {
        dbQueue.sync {
            let q = "DELETE FROM incorrect_notes WHERE level = ? AND quizGroup = ? AND questionIndex = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (level as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (quizGroup as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 3, Int32(questionIndex))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        CloudKitManager.shared.delete(type: .incorrectNote, recordName: CloudKitManager.incorrectNoteRecordName(level: level, quizGroup: quizGroup, questionIndex: questionIndex))
        NotificationCenter.default.post(name: Notification.Name("incorrectNotesDidUpdate"), object: nil)
    }
    
    func getIncorrectAnswers(level: String, quizGroup: String) -> [Int] {
        var results = [Int]()
        dbQueue.sync {
            let q = "SELECT questionIndex FROM incorrect_notes WHERE level = ? AND quizGroup = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (level as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (quizGroup as NSString).utf8String, -1, nil)
                while sqlite3_step(stmt) == SQLITE_ROW { results.append(Int(sqlite3_column_int(stmt, 0))) }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
    
    func fetchAllProgressRows() -> [ProgressRow] {
        var results = [ProgressRow]()
        dbQueue.sync {
            let q = "SELECT level, quizGroup, lastQuestionIndex FROM progress;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let level = String(cString: sqlite3_column_text(stmt, 0))
                    let quizGroup = String(cString: sqlite3_column_text(stmt, 1))
                    let index = Int(sqlite3_column_int(stmt, 2))
                    results.append(ProgressRow(level: level, quizGroup: quizGroup, lastQuestionIndex: index))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
    
    func fetchIncorrectNotes(level: String) -> [IncorrectNote] {
        var results = [IncorrectNote]()
        dbQueue.sync {
            let q = "SELECT rowid, quizGroup, questionIndex, timestamp, requiresSubscription FROM incorrect_notes WHERE level = ? ORDER BY timestamp DESC;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (level as NSString).utf8String, -1, nil)
                let formatter = ISO8601DateFormatter()
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(stmt, 0))
                    let quizGroup = String(cString: sqlite3_column_text(stmt, 1))
                    let qIndex = Int(sqlite3_column_int(stmt, 2))
                    let timeStr = String(cString: sqlite3_column_text(stmt, 3))
                    let reqSub = sqlite3_column_int(stmt, 4) != 0
                    let timestamp = formatter.date(from: timeStr) ?? Date()
                    results.append(IncorrectNote(id: id, level: level, quizGroup: quizGroup, questionIndex: qIndex, timestamp: timestamp, requiresSubscription: reqSub))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
    
    func fetchAllIncorrectNotes() -> [IncorrectNote] {
        var results = [IncorrectNote]()
        dbQueue.sync {
            let q = "SELECT rowid, level, quizGroup, questionIndex, timestamp, requiresSubscription FROM incorrect_notes;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                let formatter = ISO8601DateFormatter()
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = Int(sqlite3_column_int(stmt, 0))
                    let level = String(cString: sqlite3_column_text(stmt, 1))
                    let quizGroup = String(cString: sqlite3_column_text(stmt, 2))
                    let qIndex = Int(sqlite3_column_int(stmt, 3))
                    let timeStr = String(cString: sqlite3_column_text(stmt, 4))
                    let reqSub = sqlite3_column_int(stmt, 5) != 0
                    let timestamp = formatter.date(from: timeStr) ?? Date()
                    results.append(IncorrectNote(id: id, level: level, quizGroup: quizGroup, questionIndex: qIndex, timestamp: timestamp, requiresSubscription: reqSub))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
}
