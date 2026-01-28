import SQLite3
import Foundation
import EventKit
import UIKit

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private let eventStore = EKEventStore()
    private let calendarIdentifier = "Topik Learning"
    private var calendar: EKCalendar?
    
    var debugMode = true
    
    private init() {
        openDatabase()
        updateTableSchema()
        createTable()
        requestCalendarAccess()
        
        if debugMode {
            printAllProgress()
        }
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
        let calendars = eventStore.calendars(for: .event)
        calendar = calendars.first { $0.title == calendarIdentifier }
        
        if calendar == nil {
            let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
            newCalendar.title = calendarIdentifier
            newCalendar.cgColor = UIColor.systemBlue.cgColor
            
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
    
    deinit {
        sqlite3_close(db)
    }
    
    private func openDatabase() {
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("quiz_progress.sqlite")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("❌ SQLite 데이터베이스 열기 실패: \(String(cString: sqlite3_errmsg(db)))")
        } else if debugMode {
            print("✅ SQLite 데이터베이스 열기 성공: \(fileURL.path)")
        }
    }
    
    private func createTable() {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS progress (
            level TEXT,
            quizGroup TEXT,
            lastQuestionIndex INTEGER,
            PRIMARY KEY (level, quizGroup)
        );
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE, debugMode {
                print("✅ progress 테이블 생성 완료")
            }
        } else {
            print("❌ 테이블 생성 실패: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
    }
    
    private func updateTableSchema() {
        let checkColumnQuery = "PRAGMA table_info(progress);"
        var statement: OpaquePointer?
        var columnExists = false
        
        if sqlite3_prepare_v2(db, checkColumnQuery, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let columnName = String(cString: sqlite3_column_text(statement, 1))
                if columnName == "quizGroup" {
                    columnExists = true
                    break
                }
            }
        }
        sqlite3_finalize(statement)
        
        if !columnExists {
            let addColumnQuery = "ALTER TABLE progress ADD COLUMN quizGroup TEXT DEFAULT 'default';"
            if sqlite3_prepare_v2(db, addColumnQuery, -1, &statement, nil) == SQLITE_OK {
                if sqlite3_step(statement) == SQLITE_DONE, debugMode {
                    print("✅ quizGroup 컬럼 추가 완료")
                    resetAllProgress()
                }
            } else {
                print("❌ quizGroup 컬럼 추가 실패: \(String(cString: sqlite3_errmsg(db)))")
            }
            sqlite3_finalize(statement)
        }
    }
    
    func saveProgress(level: String, quizGroup: String, index: Int) {
        if debugMode {
            print("📝 저장 요청: 레벨=\(level), 그룹=\(quizGroup), 인덱스=\(index)")
        }
        
        sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        
        let updateQuery = "UPDATE progress SET lastQuestionIndex = ? WHERE level = ? AND quizGroup = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(index))
            sqlite3_bind_text(statement, 2, (level as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (quizGroup as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE, debugMode {
                print("✅ 진행 상태 업데이트 시도: \(index)")
            }
        } else {
            print("❌ 진행 상태 업데이트 쿼리 준비 실패: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        
        if sqlite3_changes(db) == 0 {
            insertProgress(level: level, quizGroup: quizGroup, index: index)
        }
        
        sqlite3_exec(db, "COMMIT", nil, nil, nil)
        
        DispatchQueue.main.async { [weak self] in
            self?.addCalendarEvent(level: level, quizGroup: quizGroup, index: index)
        }
        
        if debugMode {
            printAllProgress()
        }
    }
    
    private func addCalendarEvent(level: String, quizGroup: String, index: Int) {
        guard let calendar = calendar else {
            print("Calendar not available")
            return
        }
        
        // 한국어로 고정
        let isListening = quizGroup.contains("Group3")
        let typeString = isListening ? "듣기" : "읽기"
        let title = isListening ? "듣기 연습 - 레벨 \(level) 문제 \(index + 1)" : "읽기 연습 - 레벨 \(level) 문제 \(index + 1)"
        let progressNote = "\(typeString) 진행: 그룹 \(quizGroup), 문제 \(index + 1)"
        let typeTag = isListening ? "appEventType:listening" : "appEventType:reading"

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = eventStore.predicateForEvents(withStart: today, end: tomorrow, calendars: [calendar])
        let existingEvents = eventStore.events(matching: predicate).filter { event in
            (event.notes ?? "").contains(typeTag)
        }
        
        for event in existingEvents {
            do {
                try eventStore.remove(event, span: .thisEvent, commit: false)
            } catch {
                print("Error removing existing event: \(error.localizedDescription)")
            }
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.startDate = Date()
        event.endDate = Date().addingTimeInterval(3600)
        event.title = title
        event.notes = "\(progressNote)\n\(typeTag)"
        
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            print("New event saved successfully to calendar: \(calendar.title)")
        } catch {
            print("Error saving new event: \(error.localizedDescription)")
        }
    }
    
    private func insertProgress(level: String, quizGroup: String, index: Int) {
        let insertQuery = "INSERT INTO progress (level, quizGroup, lastQuestionIndex) VALUES (?, ?, ?);"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (level as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (quizGroup as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 3, Int32(index))
            
            if sqlite3_step(statement) == SQLITE_DONE, debugMode {
                print("✅ 진행 상태 초기 저장 완료: \(index) for \(level)/\(quizGroup)")
            }
        } else {
            print("❌ 진행 상태 초기 저장 쿼리 준비 실패: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
    }
    
    func loadProgress(level: String, quizGroup: String) -> Int {
        if debugMode {
            print("🔍 조회 요청: 레벨=\(level), 그룹=\(quizGroup)")
        }
        
        let selectQuery = "SELECT lastQuestionIndex FROM progress WHERE level = ? AND quizGroup = ?;"
        var statement: OpaquePointer?
        var lastIndex: Int = 0
        
        if sqlite3_prepare_v2(db, selectQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (level as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (quizGroup as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                lastIndex = Int(sqlite3_column_int(statement, 0))
                if debugMode {
                    print("✅ 진행 상태 로드 성공: \(lastIndex) for \(level)/\(quizGroup)")
                }
            } else if debugMode {
                print("ℹ️ [\(level), \(quizGroup)] 저장된 진행 데이터 없음 (기본값 0 반환)")
            }
        } else {
            print("❌ [\(level), \(quizGroup)] 진행 상태 불러오기 쿼리 준비 실패: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
        
        return lastIndex
    }
    
    func printAllProgress() {
        let selectQuery = "SELECT level, quizGroup, lastQuestionIndex FROM progress;"
        var statement: OpaquePointer?
        
        print("📊 현재 저장된 모든 진행 상태:")
        if sqlite3_prepare_v2(db, selectQuery, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let level = String(cString: sqlite3_column_text(statement, 0))
                let quizGroup = String(cString: sqlite3_column_text(statement, 1))
                let index = Int(sqlite3_column_int(statement, 2))
                
                print("   - 레벨: \(level), 그룹: \(quizGroup), 인덱스: \(index)")
            }
        } else {
            print("❌ 진행 상태 조회 실패: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(statement)
    }
    
    func resetAllProgress() {
        let deleteQuery = "DELETE FROM progress;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                print("🧹 모든 진행 상태 초기화 완료")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func resetProgress(level: String, quizGroup: String) {
        let deleteQuery = "DELETE FROM progress WHERE level = ? AND quizGroup = ?;"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (level as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (quizGroup as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("🧹 레벨 \(level), 그룹 \(quizGroup)의 진행 상태 초기화 완료")
            }
        }
        sqlite3_finalize(statement)
    }
}
