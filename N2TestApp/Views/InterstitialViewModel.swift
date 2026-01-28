import SwiftUI
import GoogleMobileAds
import Combine

@MainActor
class InterstitialViewModel: NSObject, ObservableObject, FullScreenContentDelegate {
    private var interstitialAd: InterstitialAd?
    private let adControlManager = AdControlManager.shared
    
    @Published var isAdReady = false
    @Published var isAdShowing = false
    
    // ⭐️ 타임아웃 관리
    private var timeoutWorkItem: DispatchWorkItem?
    private let adTimeoutSeconds: TimeInterval = 10

    func loadAd() async {
        // 광고제거 구매시 광고 로드하지 않음
        guard adControlManager.shouldShowInterstitialAds else {
            print("🚫 광고제거 구매로 인해 전면광고 로드 건너뜀")
            if interstitialAd != nil {
                interstitialAd = nil
                print("🗑️ 기존 전면광고 제거됨")
            }
            return
        }
        
        // ⭐️ 광고 ID 확인
        guard let adUnitID = AdConfig.interstitialID else {
            print("❌ 전면광고 ID가 설정되지 않음 (Info.plist에서 AD_INTERSTITIAL_ID 확인 필요)")
            isAdReady = false
            return
        }
        
        do {
            let ad = try await InterstitialAd.load(
                with: adUnitID,
                request: Request()
            )
            
            // 로드 완료 후 다시 한번 체크 (비동기 로드 중에 구매가 완료될 수 있음)
            guard adControlManager.shouldShowInterstitialAds else {
                print("🚫 광고 로드 완료 후 광고제거 구매 확인됨 - 광고 폐기")
                isAdReady = false
                return
            }
            
            ad.fullScreenContentDelegate = self
            interstitialAd = ad
            isAdReady = true
            print("✅ 전면광고 로드 완료")
        } catch {
            print("❌ Failed to load interstitial ad: \(error.localizedDescription)")
            isAdReady = false
        }
    }
    
    func showAd() {
        // 광고제거 구매시 광고 표시하지 않음
        guard adControlManager.shouldShowInterstitialAds else {
            print("🚫 광고제거 구매로 인해 전면광고 표시 건너뜀")
            if interstitialAd != nil {
                interstitialAd = nil
                print("🗑️ 기존 전면광고 제거됨")
            }
            return
        }
        
        // 이미 광고가 표시 중이면 건너뜀
        guard !isAdShowing else {
            print("⏸️ 이미 전면광고가 표시 중")
            return
        }
        
        guard let interstitialAd = interstitialAd else {
            print("⚠️ 전면광고가 준비되지 않았습니다.")
            return
        }
        
        // ⭐️ rootViewController 올바르게 가져오기
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            print("❌ rootViewController를 찾을 수 없음 - 전면광고 표시 실패")
            cleanupAd()
            return
        }
        
        // ⭐️ 타임아웃 설정
        setupAdTimeout()
        
        isAdShowing = true
        interstitialAd.present(from: rootViewController)
        print("🎬 전면광고 표시 시작")
    }
    
    // ⭐️ 새로 추가: 타임아웃 안전장치
    private func setupAdTimeout() {
        // 기존 타이머 취소
        timeoutWorkItem?.cancel()
        
        // 새 타이머 생성
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            if self.isAdShowing {
                print("⏰ 전면광고 타임아웃 - 강제로 상태 초기화")
                self.cleanupAd()
            }
        }
        
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + adTimeoutSeconds, execute: workItem)
    }
    
    // ⭐️ 광고제거 구매 후 기존 광고를 정리하는 메서드 추가
    func clearAdsAfterPurchase() {
        print("💳 광고제거 구매 완료 - 기존 전면광고 정리")
        
        // 타임아웃 타이머 취소
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        interstitialAd = nil
        isAdReady = false
        isAdShowing = false
    }
    
    // MARK: - FullScreenContentDelegate methods

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("📊 전면광고 노출 기록됨")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("👆 전면광고 클릭됨")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ 전면광고 표시 실패: \(error.localizedDescription)")
        
        // ⭐️ 타임아웃 타이머 취소
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        cleanupAd()
        
        // 실패 후 새 광고 로드 시도 (광고제거 구매 확인 후)
        if adControlManager.shouldShowInterstitialAds {
            Task { await loadAd() }
        }
    }
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🎬 전면광고가 표시됩니다")
        isAdShowing = true
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("👋 전면광고가 닫힐 예정입니다")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ 전면광고가 닫혔습니다")
        
        // ⭐️ 타임아웃 타이머 취소
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        cleanupAd()
        
        // 광고 닫힌 후 새 광고 로드 (광고제거 구매 확인 후)
        if adControlManager.shouldShowInterstitialAds {
            Task { await loadAd() }
        }
    }
    
    private func cleanupAd() {
        interstitialAd = nil
        isAdReady = false
        isAdShowing = false
    }
}
