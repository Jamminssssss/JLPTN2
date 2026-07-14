import Foundation
import SQLite3
import EventKit
import UIKit
import CloudKit // 🌟 필수

class ProgressManager {
    static let shared = ProgressManager()
    private var db: OpaquePointer?
    private let eventStore = EKEventStore()
    private let calendarIdentifier = "Jlpt N5 Learning"
    private var calendar: EKCalendar?
    
    // 🌟 1. 동시 접근 방지를 위한 직렬 큐(Serial Queue) 생성
    private let dbQueue = DispatchQueue(label: "com.progressmanager.dbQueue")
    
    private init() {
        setupDatabase()
        if #available(iOS 17.0, *) { requestCalendarAccess() }
    }
    
    @available(iOS 17.0, *)
    private func requestCalendarAccess() { /* 기존 로직 동일 (필요시 구현) */ }
    private func setupCalendar() { /* 기존 로직 동일 (필요시 구현) */ }
    
    private func setupDatabase() {
        // 🌟 2. try! 제거: 파일 경로 안전하게 가져오기 (EXC_BREAKPOINT 원인 차단)
        guard let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("ProgressManager: Document 디렉토리를 찾을 수 없습니다.")
            return
        }
        let fileURL = documentURL.appendingPathComponent("progress.sqlite")
        sqlite3_open(fileURL.path, &db)
        
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS WordProgress (id INTEGER PRIMARY KEY AUTOINCREMENT, wordIndex INTEGER, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);
        CREATE TABLE IF NOT EXISTS GrammarProgress (id INTEGER PRIMARY KEY AUTOINCREMENT, grammarIndex INTEGER, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);
        """
        sqlite3_exec(db, createTableQuery, nil, nil, nil)
    }
    
    func saveWordProgress(wordIndex: Int) {
        saveWordProgressLocalOnly(wordIndex: wordIndex)
        let fields: [String: CKRecordValue] = ["wordIndex": Int64(wordIndex) as CKRecordValue, "timestamp": Date() as CKRecordValue]
        CloudKitManager.shared.upload(type: .wordBookmark, recordName: CloudKitManager.wordBookmarkRecordName, fields: fields)
    }
    
    func saveWordProgressLocalOnly(wordIndex: Int, timestamp: Date = Date()) {
        // 🌟 3. dbQueue.sync 로 감싸서 다중 스레드 접근 시 대기열 형성
        dbQueue.sync {
            let q = "INSERT INTO WordProgress (wordIndex) VALUES (?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(wordIndex))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func saveGrammarProgress(grammarIndex: Int) {
        saveGrammarProgressLocalOnly(grammarIndex: grammarIndex)
        let fields: [String: CKRecordValue] = ["grammarIndex": Int64(grammarIndex) as CKRecordValue, "timestamp": Date() as CKRecordValue]
        CloudKitManager.shared.upload(type: .grammarBookmark, recordName: CloudKitManager.grammarBookmarkRecordName, fields: fields)
    }
    
    func saveGrammarProgressLocalOnly(grammarIndex: Int, timestamp: Date = Date()) {
        // 🌟 3. 스레드 동시 접근 제한
        dbQueue.sync {
            let q = "INSERT INTO GrammarProgress (grammarIndex) VALUES (?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(grammarIndex))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func getLastWordProgress() -> Int? {
        var res: Int?
        // 읽기 작업도 충돌 방지를 위해 큐에서 실행
        dbQueue.sync {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT wordIndex FROM WordProgress ORDER BY id DESC LIMIT 1;", -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW { res = Int(sqlite3_column_int(stmt, 0)) }
            }
            sqlite3_finalize(stmt)
        }
        return res
    }
    
    func getLastGrammarProgress() -> Int? {
        var res: Int?
        dbQueue.sync {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT grammarIndex FROM GrammarProgress ORDER BY id DESC LIMIT 1;", -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW { res = Int(sqlite3_column_int(stmt, 0)) }
            }
            sqlite3_finalize(stmt)
        }
        return res
    }
    
    func clearWordProgress() {
            dbQueue.sync {
                _ = sqlite3_exec(db, "DELETE FROM WordProgress;", nil, nil, nil)
            }
        }
        
        func clearGrammarProgress() {
            dbQueue.sync {
                _ = sqlite3_exec(db, "DELETE FROM GrammarProgress;", nil, nil, nil)
            }
        }
    
    deinit {
        sqlite3_close(db)
    }

    // MARK: - CloudKit Helper
    func getLastWordProgressEntry() -> (wordIndex: Int, timestamp: Date)? {
        guard let idx = getLastWordProgress() else { return nil }
        return (idx, Date())
    }
    
    func getLastGrammarProgressEntry() -> (grammarIndex: Int, timestamp: Date)? {
        guard let idx = getLastGrammarProgress() else { return nil }
        return (idx, Date())
    }
    
    func pushWordBookmarkToCloudKit(wordIndex: Int, timestamp: Date) {
        let fields: [String: CKRecordValue] = ["wordIndex": Int64(wordIndex) as CKRecordValue, "timestamp": timestamp as CKRecordValue]
        CloudKitManager.shared.upload(type: .wordBookmark, recordName: CloudKitManager.wordBookmarkRecordName, fields: fields)
    }
    
    func pushGrammarBookmarkToCloudKit(grammarIndex: Int, timestamp: Date) {
        let fields: [String: CKRecordValue] = ["grammarIndex": Int64(grammarIndex) as CKRecordValue, "timestamp": timestamp as CKRecordValue]
        CloudKitManager.shared.upload(type: .grammarBookmark, recordName: CloudKitManager.grammarBookmarkRecordName, fields: fields)
    }
}
