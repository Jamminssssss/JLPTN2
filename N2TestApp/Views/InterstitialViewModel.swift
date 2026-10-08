import SwiftUI
import GoogleMobileAds
import Combine

@MainActor
class InterstitialViewModel: NSObject, ObservableObject, FullScreenContentDelegate {
    private var interstitialAd: InterstitialAd?
    private let adControlManager = AdControlManager.shared
    private var isLoadingAd = false
    private let presentationManager = AppAdManager.shared
    private var hasAttemptedStudyAd = false
    private var loadedAt: TimeInterval?
    private var onAdFinished: (() -> Void)?
    
    @Published var isAdReady = false
    @Published var isAdShowing = false
    
    // ⭐️ 타임아웃 관리
    private var timeoutWorkItem: DispatchWorkItem?
    private let adTimeoutSeconds: TimeInterval = 10

    func loadAd() async {
        guard !isLoadingAd, !isAdShowing else { return }
        guard adControlManager.shouldShowInterstitialAds else {
            cleanupAd()
            return
        }
        if let loadedAt, isAdReady,
           ProcessInfo.processInfo.systemUptime - loadedAt < 3300 { return }
        isLoadingAd = true
        defer { isLoadingAd = false }

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
            guard !Task.isCancelled, adControlManager.shouldShowInterstitialAds else {
                print("🚫 광고 로드 완료 후 광고제거 구매 확인됨 - 광고 폐기")
                isAdReady = false
                return
            }
            
            ad.fullScreenContentDelegate = self
            interstitialAd = ad
            loadedAt = ProcessInfo.processInfo.systemUptime
            isAdReady = true
            print("✅ 전면광고 로드 완료")
        } catch {
            print("❌ Failed to load interstitial ad: \(error.localizedDescription)")
            isAdReady = false
        }
    }
    
    /// At most one attempt per screen visit. A late load never triggers presentation.
    func showAtStudyBreak(onFinished: @escaping () -> Void) {
        guard !hasAttemptedStudyAd else {
            onFinished()
            return
        }
        hasAttemptedStudyAd = true
        showAd(onFinished: onFinished)
    }

    /// Call only at an explicit break in learning; never wait for a late load.
    func showAd(onFinished: (() -> Void)? = nil) {
        guard presentationManager.canPresentFullScreenAd else {
            onFinished?()
            return
        }
        // 광고제거 구매시 광고 표시하지 않음
        guard adControlManager.shouldShowInterstitialAds else {
            cleanupAd()
            onFinished?()
            return
        }
        
        // 이미 광고가 표시 중이면 건너뜀
        guard !isAdShowing else {
            print("⏸️ 이미 전면광고가 표시 중")
            onFinished?()
            return
        }
        
        guard let interstitialAd = interstitialAd else {
            print("⚠️ 전면광고가 준비되지 않았습니다.")
            onFinished?()
            return
        }
        
        // ⭐️ rootViewController 올바르게 가져오기
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            print("❌ rootViewController를 찾을 수 없음 - 전면광고 표시 실패")
            cleanupAd()
            onFinished?()
            return
        }
        
        // Avoid presenting over an app-open ad or another full-screen screen.
        guard UIApplication.shared.applicationState == .active,
              !AppOpenAdManager.shared.isAdShowing,
              rootViewController.presentedViewController == nil else {
            onFinished?()
            return
        }

        guard let loadedAt, ProcessInfo.processInfo.systemUptime - loadedAt < 3300,
              presentationManager.beginFullScreenAd(.interstitial) else {
            onFinished?()
            return
        }
        // Protect presentation startup, not the time spent watching an ad.
        setupAdTimeout()
        
        onAdFinished = onFinished
        isAdReady = false
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
        
        // Keep an already presented ad alive until its dismissal callback.
        guard !isAdShowing else { return }
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        cleanupAd()
    }
    
    // MARK: - FullScreenContentDelegate methods

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("📊 전면광고 노출 기록됨")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("👆 전면광고 클릭됨")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        guard interstitialAd === (ad as AnyObject) else { return }
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
        guard interstitialAd === (ad as AnyObject) else { return }
        print("🎬 전면광고가 표시됩니다")
        // The timeout protects presentation startup, not the time spent watching.
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        isAdShowing = true
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("👋 전면광고가 닫힐 예정입니다")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard interstitialAd === (ad as AnyObject) else { return }
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
        if isAdShowing { presentationManager.endFullScreenAd(.interstitial) }
        interstitialAd = nil
        loadedAt = nil
        isAdReady = false
        isAdShowing = false
        let completion = onAdFinished
        onAdFinished = nil
        completion?()
    }
}
