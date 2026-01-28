import SwiftUI
import GoogleMobileAds
import Combine

@MainActor
class AppOpenAdManager: NSObject, FullScreenContentDelegate, ObservableObject {
    @Published var isAdLoading = false
    @Published var isAdShowing = false
    
    var appOpenAd: AppOpenAd?
    var isLoadingAd = false
    var isShowingAd = false
    var loadTime: Date?
    let fourHoursInSeconds = TimeInterval(3600 * 4)
    
    // ⭐️ 타임아웃 타이머 추가
    private var timeoutWorkItem: DispatchWorkItem?
    private let adTimeoutSeconds: TimeInterval = 10 // 10초 타임아웃
    
    private let adControlManager = AdControlManager.shared

    static let shared = AppOpenAdManager()
    
    private override init() {
        super.init()
    }

    func loadAd() async {
        // 광고제거 구매시 광고 로드하지 않음 - 실시간 체크
        guard adControlManager.shouldShowAppOpenAds else {
            print("🚫 광고제거 구매로 인해 앱 오픈 광고 로드 건너뜀")
            // 기존에 로드된 광고가 있다면 제거
            if appOpenAd != nil {
                appOpenAd = nil
                print("🗑️ 기존 앱 오픈 광고 제거됨")
            }
            return
        }
        
        // ⭐️ 광고 ID가 없으면 로드하지 않음
        guard let adUnitID = AdConfig.appOpenID else {
            print("❌ 앱 오픈 광고 ID가 설정되지 않음")
            isLoadingAd = false
            isAdLoading = false
            return
        }
        
        // 이미 로딩 중이거나 광고가 존재하면 건너뜀
        if isLoadingAd || isAdAvailable() {
            return
        }

        isLoadingAd = true
        isAdLoading = true

        do {
            // ⭐️ 언래핑된 adUnitID 사용
            let ad = try await AppOpenAd.load(
                with: adUnitID, request: Request())
            
            // 로드 완료 후 다시 한번 체크 (비동기 로드 중에 구매가 완료될 수 있음)
            guard adControlManager.shouldShowAppOpenAds else {
                print("🚫 광고 로드 완료 후 광고제거 구매 확인됨 - 광고 폐기")
                isLoadingAd = false
                isAdLoading = false
                return
            }
            
            ad.fullScreenContentDelegate = self
            self.appOpenAd = ad
            self.loadTime = Date()
            print("✅ 앱 오픈 광고 로드 완료")
        } catch {
            print("❌ 앱 오픈 광고 로드 실패: \(error.localizedDescription)")
        }

        isLoadingAd = false
        isAdLoading = false
    }

    private func wasLoadTimeLessThanFourHoursAgo() -> Bool {
        guard let loadTime = loadTime else { return false }
        return Date().timeIntervalSince(loadTime) < fourHoursInSeconds
    }

    private func isAdAvailable() -> Bool {
        return appOpenAd != nil && wasLoadTimeLessThanFourHoursAgo()
    }

    func showAdIfAvailable() {
        // 광고제거 구매시 광고 표시하지 않음 - 실시간 체크
        guard adControlManager.shouldShowAppOpenAds else {
            print("🚫 광고제거 구매로 인해 앱 오픈 광고 표시 건너뜀")
            // 기존에 로드된 광고가 있다면 제거
            if appOpenAd != nil {
                appOpenAd = nil
                print("🗑️ 기존 앱 오픈 광고 제거됨")
            }
            return
        }
        
        // 이미 광고가 표시 중이면 건너뜀
        guard !isShowingAd else {
            print("⏸️ 이미 광고가 표시 중")
            return
        }

        if !isAdAvailable() {
            print("📱 광고가 없어서 새로 로드 시도")
            Task { await loadAd() }
            return
        }

        if let ad = appOpenAd {
            print("🎬 앱 오픈 광고 표시 시작")
            isShowingAd = true
            
            // ⭐️ 수정: rootViewController 올바르게 가져오기
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                print("❌ rootViewController를 찾을 수 없음 - 광고 표시 실패")
                isShowingAd = false
                appOpenAd = nil
                // 실패 시 새 광고 로드 시도
                Task { await loadAd() }
                return
            }
            
            // ⭐️ 타임아웃 설정: 10초 후에도 광고가 닫히지 않으면 강제로 상태 초기화
            setupAdTimeout()
            
            // 광고 표시
            ad.present(from: rootViewController)
        }
    }
    
    // ⭐️ 새로 추가: 타임아웃 안전장치
    private func setupAdTimeout() {
        // 기존 타이머 취소
        timeoutWorkItem?.cancel()
        
        // 새 타이머 생성
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            if self.isShowingAd || self.isAdShowing {
                print("⏰ 광고 타임아웃 - 강제로 상태 초기화")
                self.resetAdState()
            }
        }
        
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + adTimeoutSeconds, execute: workItem)
    }
    
    // ⭐️ 새로 추가: 광고 상태 초기화
    private func resetAdState() {
        appOpenAd = nil
        isShowingAd = false
        isAdShowing = false
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        print("🔄 광고 상태 초기화 완료")
        
        // 다음 광고 로드 (광고제거 구매 확인 후)
        if adControlManager.shouldShowAppOpenAds {
            Task { await loadAd() }
        }
    }
    
    // 광고제거 구매 후 기존 광고를 정리하는 메서드 추가
    func clearAdsAfterPurchase() {
        print("💳 광고제거 구매 완료 - 기존 광고 정리")
        
        // 타임아웃 타이머 취소
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        // 현재 표시중인 광고가 있다면 닫기 (앱오픈광고는 수동으로 닫을 수 없으므로 상태만 초기화)
        if isShowingAd || isAdShowing {
            print("⚠️ 광고가 현재 표시 중이지만 상태만 초기화")
        }
        
        appOpenAd = nil
        loadTime = nil
        isLoadingAd = false
        isAdLoading = false
        isShowingAd = false
        isAdShowing = false
    }

    // MARK: - FullScreenContentDelegate methods
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("🎬 앱 오픈 광고가 표시됩니다")
        isAdShowing = true
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✖️ 앱 오픈 광고가 닫혔습니다")
        
        // ⭐️ 타임아웃 타이머 취소
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        appOpenAd = nil
        isShowingAd = false
        isAdShowing = false
        
        // 광고 닫힌 후 새 광고 로드 (광고제거 구매 확인 후)
        if adControlManager.shouldShowAppOpenAds {
            Task { await loadAd() }
        }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        print("❌ 앱 오픈 광고 표시 실패: \(error.localizedDescription)")
        
        // ⭐️ 타임아웃 타이머 취소
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        appOpenAd = nil
        isShowingAd = false
        isAdShowing = false
        
        // 실패 후 새 광고 로드 시도 (광고제거 구매 확인 후)
        if adControlManager.shouldShowAppOpenAds {
            Task { await loadAd() }
        }
    }
}
