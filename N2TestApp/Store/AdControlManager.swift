import Foundation
import StoreKit
import Combine

@MainActor
class AdControlManager: ObservableObject {
    static let shared = AdControlManager()
    
    @Published var shouldShowAds: Bool = true
    
    private init() {
        // ✅ 초기 상태 설정 (StoreKitManager 직접 참조)
        updateAdVisibility()
        
        // ✅ Notification 리스너 등록
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePurchaseStatusChanged),
            name: .purchaseStatusChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handlePurchaseStatusChanged() {
        Task { @MainActor in
            updateAdVisibility()
        }
    }
    
    func updateAdVisibility() {
        let previousState = shouldShowAds
        
        // ✅ StoreKitManager의 상태를 직접 확인
        let newState = StoreKitManager.shared.shouldShowAds
        
        shouldShowAds = newState
        
        print("🎯 광고 표시 상태: \(shouldShowAds ? "표시" : "숨김")")
        print("   - 구독 중: \(StoreKitManager.shared.isSubscribed)")
        print("   - 프리미엄: \(StoreKitManager.shared.isPremium)")
        
        // 광고 상태가 표시에서 숨김으로 변경되었을 때 (구매 완료)
        if previousState && !shouldShowAds {
            print("💳 구독 구매 감지 - 앱 오픈 광고 정리")
            AppOpenAdManager.shared.clearAdsAfterPurchase()
        }
    }
    
    // ✅ 편의 프로퍼티들
    var shouldShowBannerAds: Bool {
        shouldShowAds
    }
    
    var shouldShowInterstitialAds: Bool {
        shouldShowAds
    }
    
    var shouldShowAppOpenAds: Bool {
        shouldShowAds
    }
    
    // ✅ 수동 새로고침 메서드
    func refresh() {
        updateAdVisibility()
    }
}
