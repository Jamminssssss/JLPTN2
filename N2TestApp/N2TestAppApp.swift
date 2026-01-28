//
//  N2TestAppApp.swift
//  N2TestApp
//
//  Created by JeaminPark on 8/27/25.
//

import SwiftUI
import GoogleMobileAds

@main
struct N2TestAppApp: App {
    
    // ⭐️ 앱 시작 시 초기화
    init() {
        print("🚀 앱 초기화 시작")
        configureApp()
        print("✅ 앱 초기화 완료")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    // MARK: - App Configuration
    
    private func configureApp() {
        print("🔧 configureApp 시작")
        validateAndInitializeAds()
        print("✅ configureApp 완료")
    }
    
    private func validateAndInitializeAds() {
        print("📋 광고 검증 시작")
        
        #if DEBUG
        print("=== 광고 설정 검증 ===")
        let configs: [(String, String?)] = [
            ("App ID", AdConfig.appID),
            ("App Open ID", AdConfig.appOpenID),
            ("Banner Top ID", AdConfig.bannerTopID),
            ("Banner Bottom ID", AdConfig.bannerBottomID),
            ("Interstitial ID", AdConfig.interstitialID)
        ]
        
        var hasError = false
        for (name, value) in configs {
            if let value = value, !value.isEmpty {
                print("✅ \(name): \(value.prefix(30))...")
            } else {
                print("❌ \(name): NOT SET")
                hasError = true
            }
        }
        
        if hasError {
            print("⚠️ 일부 광고 ID가 설정되지 않았습니다.")
            print("   1. Xcode → Target → Build Settings → User-Defined 확인")
            print("   2. Info.plist 확인")
            print("   3. Xcode Cloud 환경 변수 확인")
            print("   앱이 크래시할 수 있습니다!")
        }
        print("======================")
        #endif
        
        print("🎯 AdConfig.appID 확인: \(AdConfig.appID ?? "NIL")")
        
        // Google Mobile Ads 초기화
        guard let appID = AdConfig.appID, !appID.isEmpty else {
            print("❌ CRITICAL ERROR: GADApplicationIdentifier가 설정되지 않음!")
            print("   Google Mobile Ads를 초기화할 수 없습니다.")
            
            #if DEBUG
            // 디버그 모드에서는 명확하게 에러 표시
            fatalError("GADApplicationIdentifier must be set in Info.plist and Build Settings!")
            #else
            return
            #endif
        }
        
        print("🚀 MobileAds 초기화 시작...")
        
        // ⭐️ 올바른 초기화 방법
        MobileAds.shared.start { status in
            print("✅ Google Mobile Ads 초기화 완료")
            
            #if DEBUG
            print("📊 어댑터 상태:")
            for (adapter, adapterStatus) in status.adapterStatusesByClassName {
                let stateName: String
                switch adapterStatus.state {
                case .notReady:
                    stateName = "준비 안 됨"
                case .ready:
                    stateName = "준비 완료"
                @unknown default:
                    stateName = "알 수 없음"
                }
                print("  - \(adapter): \(stateName)")
                
                if adapterStatus.state == .notReady {
                    print("    이유: \(adapterStatus.description)")
                }
            }
            #endif
        }
    }
}



