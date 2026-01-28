import SwiftUI
import GoogleMobileAds
import UIKit

// MARK: - BannerAdView: UIViewRepresentable

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    @ObservedObject private var adControlManager = AdControlManager.shared

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width))
        banner.adUnitID = adUnitID
        
        // ⭐️ rootViewController 올바르게 가져오기
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            banner.rootViewController = rootVC
        } else {
            print("⚠️ rootViewController를 찾을 수 없음")
        }
        
        banner.delegate = context.coordinator
        banner.alpha = 0 // 처음엔 숨김
        
        // 광고제거 구매 확인 후 로드
        if adControlManager.shouldShowBannerAds {
            banner.load(Request())
            print("🔄 배너 광고 로드 시작 (ID: \(adUnitID.prefix(20))...)")
        } else {
            print("🚫 광고제거 구매로 인해 배너 광고 로드 건너뜀")
        }
        
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // 광고 상태가 변경되었을 때 처리
        if !adControlManager.shouldShowBannerAds {
            // 광고제거 구매 완료시 배너 제거
            print("🗑️ 광고제거 구매로 인해 배너 광고 제거")
            UIView.animate(withDuration: 0.3) {
                uiView.alpha = 0
            } completion: { _ in
                uiView.removeFromSuperview()
            }
        } else if uiView.superview == nil {
            // 광고 표시가 필요하지만 뷰가 제거된 경우 다시 로드
            print("🔄 배너 광고 다시 로드 필요")
            uiView.load(Request())
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ 배너 광고 로드 완료")
            
            // 광고 로드 완료 후 다시 한번 구매 상태 확인
            guard AdControlManager.shared.shouldShowBannerAds else {
                print("🚫 광고 로드 완료 후 광고제거 구매 확인됨 - 배너 광고 숨김")
                UIView.animate(withDuration: 0.3) {
                    bannerView.alpha = 0
                } completion: { _ in
                    bannerView.removeFromSuperview()
                }
                return
            }
            
            UIView.animate(withDuration: 0.5) {
                bannerView.alpha = 1.0
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ 배너 광고 로드 실패: \(error.localizedDescription)")
            bannerView.removeFromSuperview()
        }

        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            print("📊 배너 광고 노출 기록됨")
        }

        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            print("➡️ 배너 광고가 전체 화면 콘텐츠를 표시합니다")
        }

        func bannerViewWillDismissScreen(_ bannerView: BannerView) {
            print("⬅️ 배너 광고 전체 화면 콘텐츠가 닫힐 예정입니다")
        }

        func bannerViewDidDismissScreen(_ bannerView: BannerView) {
            print("🗙 배너 광고 전체 화면 콘텐츠가 닫혔습니다")
        }
    }
}

// MARK: - Adaptive Banner Views

struct AdaptiveBannerView: View {
    @ObservedObject private var adControlManager = AdControlManager.shared
    let adUnitID: String
    
    var body: some View {
        Group {
            if adControlManager.shouldShowBannerAds {
                BannerAdView(adUnitID: adUnitID)
            } else {
                // 광고 제거시 빈 공간
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 0)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .purchaseStatusChanged)) { _ in
            // 구매 상태 변경 시 뷰 업데이트 강제 트리거
            print("🔔 구매 상태 변경 감지 - 배너 광고 상태 업데이트")
        }
    }
}

struct AdaptiveTopBannerView: View {
    @ObservedObject private var adControlManager = AdControlManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // 화면 방향과 기기에 따른 배너 높이 계산
    private var bannerHeight: CGFloat {
        if !adControlManager.shouldShowBannerAds {
            return 0
        }
        
        if horizontalSizeClass == .regular && verticalSizeClass == .compact {
            return 90 // iPad 가로 모드
        } else if horizontalSizeClass == .regular {
            return 100 // iPad 세로 모드
        } else if horizontalSizeClass == .compact && verticalSizeClass == .compact {
            return 32 // iPhone 가로 모드
        } else {
            return 50 // iPhone 세로 모드
        }
    }
    
    var body: some View {
        Group {
            if adControlManager.shouldShowBannerAds {
                // ⭐️ 광고 ID 확인
                if let topAdID = AdConfig.bannerTopID {
                    GeometryReader { geometry in
                        BannerAdView(adUnitID: topAdID)
                            .frame(width: geometry.size.width, height: bannerHeight)
                            .clipped()
                    }
                    .frame(height: bannerHeight)
                    .background(Color.gray.opacity(0.1))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    // 광고 ID가 없으면 빈 공간
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 0)
                        .onAppear {
                            print("⚠️ 상단 배너 광고 ID가 설정되지 않음")
                        }
                }
            } else {
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: adControlManager.shouldShowBannerAds)
        .onReceive(NotificationCenter.default.publisher(for: .purchaseStatusChanged)) { _ in
            print("🔔 상단 배너: 구매 상태 변경 감지")
        }
    }
}

struct AdaptiveBottomBannerView: View {
    @ObservedObject private var adControlManager = AdControlManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var bannerHeight: CGFloat {
        if !adControlManager.shouldShowBannerAds {
            return 0
        }
        
        if horizontalSizeClass == .regular && verticalSizeClass == .compact {
            return 90 // iPad 가로 모드
        } else if horizontalSizeClass == .regular {
            return 100 // iPad 세로 모드
        } else if horizontalSizeClass == .compact && verticalSizeClass == .compact {
            return 32 // iPhone 가로 모드
        } else {
            return 50 // iPhone 세로 모드
        }
    }
    
    var body: some View {
        Group {
            if adControlManager.shouldShowBannerAds {
                // ⭐️ 광고 ID 확인
                if let bottomAdID = AdConfig.bannerBottomID {
                    GeometryReader { geometry in
                        BannerAdView(adUnitID: bottomAdID)
                            .frame(width: geometry.size.width, height: bannerHeight)
                            .clipped()
                    }
                    .frame(height: bannerHeight)
                    .background(Color.gray.opacity(0.1))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    // 광고 ID가 없으면 빈 공간
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 0)
                        .onAppear {
                            print("⚠️ 하단 배너 광고 ID가 설정되지 않음")
                        }
                }
            } else {
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: adControlManager.shouldShowBannerAds)
        .onReceive(NotificationCenter.default.publisher(for: .purchaseStatusChanged)) { _ in
            print("🔔 하단 배너: 구매 상태 변경 감지")
        }
    }
}
