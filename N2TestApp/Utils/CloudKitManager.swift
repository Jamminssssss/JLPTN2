import Foundation
import CloudKit

enum CKSyncRecordType: String {
    case examProgress = "ExamProgress"
    case incorrectNote = "IncorrectNote"
    case wordBookmark = "WordBookmark"
    case grammarBookmark = "GrammarBookmark"
}

extension Notification.Name {
    // 🌟 에러 원인 해결: topik -> jlpt 로 이름 완벽 통일
    static let jlptCloudRestoreCompleted = Notification.Name("jlptCloudRestoreCompleted")
}

final class CloudKitManager {
    static let shared = CloudKitManager()

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private(set) var isCloudKitAvailable = false

    private enum SingletonRecordName {
        static let wordBookmark = "wordBookmark_latest"
        static let grammarBookmark = "grammarBookmark_latest"
    }

    private static let knownExamProgressKeys: [(level: String, quizGroup: String)] = {
        var keys: [(String, String)] = []
        // 🌟 에러 원인 해결: N5TestApp 기준이므로 1...10 이 아니라 1...5 로 변경
        for set in 1...5 {
            keys.append(("JLPTN2", "Group1_set\(set)"))
            keys.append(("JLPTN2Audio", "Group2_set\(set)"))
        }
        return keys
    }()

    private init() {
        container = CKContainer(identifier: "iCloud.com.Jaemin.N2Study") // Identifier 확인 요망
        privateDatabase = container.privateCloudDatabase

        Task { await checkAccountStatus() }

        NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.checkAccountStatus() }
        }
    }

    @discardableResult
    func checkAccountStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            isCloudKitAvailable = (status == .available)
        } catch {
            isCloudKitAvailable = false
        }
        return isCloudKitAvailable
    }

    func upload(type: CKSyncRecordType, recordName: String, fields: [String: CKRecordValue]) {
        Task {
            guard await ensureAvailable() else { return }
            let recordID = CKRecord.ID(recordName: recordName)
            do {
                let record = (try? await privateDatabase.record(for: recordID)) ?? CKRecord(recordType: type.rawValue, recordID: recordID)
                for (key, value) in fields { record[key] = value }
                _ = try await privateDatabase.save(record)
            } catch let error as CKError where error.code == .serverRecordChanged {
                if let serverRecord = error.serverRecord {
                    for (key, value) in fields { serverRecord[key] = value }
                    _ = try? await privateDatabase.save(serverRecord)
                }
            } catch { }
        }
    }

    func delete(type: CKSyncRecordType, recordName: String) {
        Task {
            guard await ensureAvailable() else { return }
            _ = try? await privateDatabase.deleteRecord(withID: CKRecord.ID(recordName: recordName))
        }
    }

    private func ensureAvailable() async -> Bool {
        if isCloudKitAvailable { return true }
        return await checkAccountStatus()
    }

    private func fetchSingletonRecord(recordName: String) async -> CKRecord? {
        try? await privateDatabase.record(for: CKRecord.ID(recordName: recordName))
    }

    private func fetchAllRecords(ofType type: CKSyncRecordType) async -> [CKRecord] {
        var allRecords: [CKRecord] = []
        let query = CKQuery(recordType: type.rawValue, predicate: NSPredicate(value: true))
        do {
            var result = try await privateDatabase.records(matching: query)
            allRecords.append(contentsOf: result.matchResults.compactMap { try? $0.1.get() })
            while let cursor = result.queryCursor {
                result = try await privateDatabase.records(continuingMatchFrom: cursor)
                allRecords.append(contentsOf: result.matchResults.compactMap { try? $0.1.get() })
            }
        } catch { }
        return allRecords
    }

    @discardableResult
    func restoreData() async -> Bool {
        guard await checkAccountStatus() else { return false }

        async let progress: Void = restoreExamProgress()
        async let notes: Void = restoreIncorrectNotes()
        async let word: Void = restoreWordBookmark()
        async let grammar: Void = restoreGrammarBookmark()
        _ = await (progress, notes, word, grammar)

        await MainActor.run { NotificationCenter.default.post(name: .jlptCloudRestoreCompleted, object: nil) }
        return true
    }

    private func restoreExamProgress() async {
        let recordIDs = Self.knownExamProgressKeys.map { CKRecord.ID(recordName: CloudKitManager.progressRecordName(level: $0.level, quizGroup: $0.quizGroup)) }
        do {
            let results = try await privateDatabase.records(for: recordIDs)
            for (_, result) in results {
                guard case .success(let record) = result,
                      let level = record["level"] as? String,
                      let quizGroup = record["quizGroup"] as? String,
                      let lastIndex = record["lastQuestionIndex"] as? Int64 else { continue }
                DatabaseManager.shared.saveProgressLocalOnly(level: level, quizGroup: quizGroup, index: Int(lastIndex))
            }
        } catch { }
    }

    private func restoreIncorrectNotes() async {
            for record in await fetchAllRecords(ofType: .incorrectNote) {
                guard let level = record["level"] as? String,
                      let quizGroup = record["quizGroup"] as? String,
                      let questionIndex = record["questionIndex"] as? Int64 else { continue }
                
                // 🌟 수정됨: 예전 버전에 저장되어 requiresSubscription 값이 없는 오답노트도 무시하지 않고 복원
                let reqSub = record["requiresSubscription"] as? Int64 ?? 0
                let timestamp = record["timestamp"] as? Date ?? Date()
                
                DatabaseManager.shared.upsertIncorrectNoteLocalOnly(level: level, quizGroup: quizGroup, questionIndex: Int(questionIndex), timestamp: timestamp, requiresSubscription: reqSub == 1)
        }
    }

    private func restoreWordBookmark() async {
        guard let record = await fetchSingletonRecord(recordName: SingletonRecordName.wordBookmark),
              let idx = record["wordIndex"] as? Int64 else { return }
        ProgressManager.shared.saveWordProgressLocalOnly(wordIndex: Int(idx))
    }

    private func restoreGrammarBookmark() async {
        guard let record = await fetchSingletonRecord(recordName: SingletonRecordName.grammarBookmark),
              let idx = record["grammarIndex"] as? Int64 else { return }
        ProgressManager.shared.saveGrammarProgressLocalOnly(grammarIndex: Int(idx))
    }

    func backfillLocalDataToCloud() {
        guard isCloudKitAvailable else { return }
        for row in DatabaseManager.shared.fetchAllProgressRows() {
            DatabaseManager.shared.pushProgressToCloudKit(level: row.level, quizGroup: row.quizGroup, index: row.lastQuestionIndex)
        }
        for note in DatabaseManager.shared.fetchAllIncorrectNotes() {
            DatabaseManager.shared.pushIncorrectNoteToCloudKit(level: note.level, quizGroup: note.quizGroup, questionIndex: note.questionIndex, timestamp: note.timestamp, requiresSubscription: note.requiresSubscription)
        }
        if let word = ProgressManager.shared.getLastWordProgressEntry() {
            ProgressManager.shared.pushWordBookmarkToCloudKit(wordIndex: word.wordIndex, timestamp: word.timestamp)
        }
        if let grammar = ProgressManager.shared.getLastGrammarProgressEntry() {
            ProgressManager.shared.pushGrammarBookmarkToCloudKit(grammarIndex: grammar.grammarIndex, timestamp: grammar.timestamp)
        }
    }

    static func progressRecordName(level: String, quizGroup: String) -> String { "progress|\(level)|\(quizGroup)" }
    static func incorrectNoteRecordName(level: String, quizGroup: String, questionIndex: Int) -> String { "note|\(level)|\(quizGroup)|\(questionIndex)" }
    static var wordBookmarkRecordName: String { SingletonRecordName.wordBookmark }
    static var grammarBookmarkRecordName: String { SingletonRecordName.grammarBookmark }
}
