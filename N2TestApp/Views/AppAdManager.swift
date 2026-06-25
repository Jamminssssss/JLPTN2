// AppAdManager.swift - 새로운 파일로 생성하세요
import SwiftUI

// 앱 레벨 광고 상태 관리자 - 싱글톤 패턴
class AppAdManager: ObservableObject {
    static let shared = AppAdManager()
    
    // 각 뷰별 광고 표시 상태 (앱이 실행되는 동안 유지)
    @Published var hasShownReadingAd = false
    @Published var hasShownListeningAd = false
    @Published var hasShownWordListAd = false
    @Published var hasShownGrammarAd = false
    @Published var hasPracticeWordAd = false
    private init() {}
    
    // 앱 종료시 상태 초기화 (앱 재시작시 자동으로 false로 초기화됨)
    func resetOnAppTermination() {
        hasShownReadingAd = false
        hasShownListeningAd = false
        hasShownWordListAd = false
        hasShownGrammarAd = false
        hasPracticeWordAd = false
    }
}
