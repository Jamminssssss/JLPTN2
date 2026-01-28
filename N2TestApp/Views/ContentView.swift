import SwiftUI
import StoreKit
import UIKit
import AppTrackingTransparency
import AdSupport

struct ContentView: View {
    @State private var showPurchaseView = false
    @StateObject private var adManager = AppOpenAdManager.shared
    @State private var hasShownOpenAdThisSession = false
    @State private var hasRequestedATT = false
    
    // ⭐️ 추가: 광고 로딩/표시 상태 추적
    @State private var isInitializing = true
    @State private var adTimeoutWorkItem: DispatchWorkItem?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @StateObject private var storeManager = StoreKitManager.shared
    @ObservedObject private var adControlManager = AdControlManager.shared

    private var isLandscape: Bool {
        verticalSizeClass == .compact || horizontalSizeClass == .regular
    }

    var body: some View {
        ZStack {
            // 메인 콘텐츠
            NavigationStack {
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        AdaptiveTopBannerView()

                        ZStack {
                            backgroundColor.ignoresSafeArea()
                            GeometryReader { contentGeometry in
                                let availableWidth = contentGeometry.size.width
                                let availableHeight = contentGeometry.size.height

                                if isLandscape {
                                    landscapeLayout(width: availableWidth, height: availableHeight)
                                } else {
                                    portraitLayout(width: availableWidth, height: availableHeight)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        AdaptiveBottomBannerView()
                    }
                }
            }
            .ignoresSafeArea(.container, edges: [.leading, .trailing])
            
            // ⭐️ 추가: 초기화 중 오버레이 (광고 표시 중에만)
            if isInitializing && adControlManager.shouldShowAppOpenAds {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onAppear {
                        setupAdTimeout()
                    }
            }
        }
        .sheet(isPresented: $showPurchaseView) {
            PurchaseView()
        }
        .onAppear {
            print("📱 ContentView appeared")
            
            // ✅ ATT 권한 요청 (딱 1회)
            if #available(iOS 14, *), !hasRequestedATT {
                hasRequestedATT = true
                requestTrackingPermission()
            }

            // ⭐️ 초기화 로직 개선
            Task {
                // StoreKit 초기화 대기
                while storeManager.products.isEmpty && !storeManager.isLoading {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }

                await storeManager.updateCustomerProductStatus()
                
                // ⭐️ UI가 안정화될 때까지 짧은 딜레이
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초

                // 광고 표시 로직
                if !hasShownOpenAdThisSession {
                    if adControlManager.shouldShowAppOpenAds {
                        print("🎬 첫 실행 - 앱 오픈 광고 준비")
                        await adManager.loadAd()
                        
                        // ⭐️ 광고 로드 확인 후 표시
                        if adManager.appOpenAd != nil {
                            adManager.showAdIfAvailable()
                        } else {
                            print("⚠️ 광고 로드 실패 - 메인 화면 표시")
                            isInitializing = false
                        }
                    } else {
                        print("🚫 광고제거 구매로 인해 앱 오픈 광고 건너뜀")
                        isInitializing = false
                    }
                    hasShownOpenAdThisSession = true
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
        }
        // ⭐️ 광고 상태 변경 감지
        .onChange(of: adManager.isAdShowing) { _, isShowing in
            if !isShowing && isInitializing {
                // 광고가 닫히면 초기화 완료
                print("✅ 광고 닫힘 - 메인 화면 표시")
                cancelAdTimeout()
                isInitializing = false
            }
        }
    }
    
    // ⭐️ 새로 추가: ATT 권한 요청 메서드
    private func requestTrackingPermission() {
        // UI가 준비된 후 요청
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("✅ ATT 권한 허용됨")
                case .denied:
                    print("❌ ATT 권한 거부됨")
                case .notDetermined:
                    print("⚠️ ATT 권한 미결정")
                case .restricted:
                    print("⚠️ ATT 권한 제한됨")
                @unknown default:
                    print("⚠️ ATT 알 수 없는 상태")
                }
            }
        }
    }
    
    // ⭐️ 새로 추가: 광고 타임아웃 설정
    private func setupAdTimeout() {
        cancelAdTimeout() // 기존 타이머 취소
        
        let workItem = DispatchWorkItem { [self] in
            if isInitializing {
                print("⏰ 광고 타임아웃 (10초) - 강제로 메인 화면 표시")
                isInitializing = false
            }
        }
        
        adTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: workItem)
    }
    
    // ⭐️ 새로 추가: 타이머 취소
    private func cancelAdTimeout() {
        adTimeoutWorkItem?.cancel()
        adTimeoutWorkItem = nil
    }
    
    // ⭐️ ScenePhase 변경 처리 메서드 분리
    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        // 백그라운드에서 포그라운드로 전환
        if oldPhase == .background && newPhase == .active {
            print("📱 앱이 포그라운드로 전환됨")
            
            // 이미 광고를 표시했거나 현재 표시 중이면 건너뜀
            guard !hasShownOpenAdThisSession && !adManager.isAdShowing else {
                print("⏸️ 광고 표시 건너뜀 (이미 표시함 또는 표시 중)")
                return
            }

            Task {
                await storeManager.updateCustomerProductStatus()

                if adControlManager.shouldShowAppOpenAds {
                    print("🎬 포그라운드 전환 - 앱 오픈 광고 준비")
                    await adManager.loadAd()
                    
                    // ⭐️ 광고 로드 확인 후 표시
                    if adManager.appOpenAd != nil {
                        adManager.showAdIfAvailable()
                        hasShownOpenAdThisSession = true
                    } else {
                        print("⚠️ 광고 로드 실패 - 광고 표시 건너뜀")
                    }
                } else {
                    print("🚫 광고제거 구매로 인해 앱 오픈 광고 건너뜀")
                    hasShownOpenAdThisSession = true
                }
            }
        }
        
        // 포그라운드에서 백그라운드로 전환
        if oldPhase == .active && newPhase == .background {
            print("📱 앱이 백그라운드로 전환됨")
            // 다음 포그라운드 전환 시 광고를 다시 표시할 수 있도록 리셋
            hasShownOpenAdThisSession = false
            cancelAdTimeout()
        }
    }

    // MARK: - Portrait Layout (세로 모드)
    private func portraitLayout(width: CGFloat, height: CGFloat) -> some View {
        let horizontalPadding: CGFloat = 20
        let verticalPadding: CGFloat = 20
        let itemSpacing: CGFloat = 15
        
        let buttonWidth = width - horizontalPadding * 2
        let minButtonHeight: CGFloat = 80
        let idealButtonHeight = max(minButtonHeight, (height - verticalPadding * 2 - itemSpacing * 4) / 5)
        
        return ScrollView {
            VStack(spacing: itemSpacing) {
                NavigationLink(destination: ReadingView(isTabBarHidden: .constant(false))) {
                    dynamicMenuButton(title: "menu.reading", icon: "book.fill", color: .blue, width: buttonWidth, height: idealButtonHeight)
                }
                
                NavigationLink(destination: ListeningView(isTabBarHidden: .constant(false))) {
                    dynamicMenuButton(title: "menu.listening", icon: "headphones", color: .green, width: buttonWidth, height: idealButtonHeight)
                }
                
                NavigationLink(destination: WordListView()) {
                    dynamicMenuButton(title: "menu.wordlist", icon: "character.book.closed.fill", color: .purple, width: buttonWidth, height: idealButtonHeight)
                }
                
                NavigationLink(destination: GrammarPracticeView()) {
                    dynamicMenuButton(title: "menu.grammar", icon: "graduationcap.fill", color: .red, width: buttonWidth, height: idealButtonHeight)
                }
                
                if storeManager.isSubscribed {
                    NavigationLink(destination: PracticeWordView()) {
                        dynamicMenuButton(title: "menu.writing", icon: "pencil", color: .orange, width: buttonWidth, height: idealButtonHeight)
                    }
                } else {
                    Button(action: { showPurchaseView = true }) {
                        dynamicMenuButton(title: "menu.writing", icon: "pencil.and.outline", color: .orange, width: buttonWidth, height: idealButtonHeight)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
        .frame(width: width, height: height)
    }
    
    // MARK: - Landscape Layout (가로 모드)
    private func landscapeLayout(width: CGFloat, height: CGFloat) -> some View {
        let horizontalPadding: CGFloat = 20
        let verticalPadding: CGFloat = 15
        let itemSpacing: CGFloat = 12
        
        let buttonWidth = width - horizontalPadding * 2
        let minButtonHeight: CGFloat = 70
        let idealButtonHeight = max(minButtonHeight, (height - verticalPadding * 2 - itemSpacing * 4) / 5)
        
        return ScrollView {
            VStack(spacing: itemSpacing) {
                NavigationLink(destination: ReadingView(isTabBarHidden: .constant(false))) {
                    dynamicMenuButton(title: "menu.reading", icon: "book.fill", color: .blue, width: buttonWidth, height: idealButtonHeight)
                }
                
                NavigationLink(destination: ListeningView(isTabBarHidden: .constant(false))) {
                    dynamicMenuButton(title: "menu.listening", icon: "headphones", color: .green, width: buttonWidth, height: idealButtonHeight)
                }
                
                NavigationLink(destination: WordListView()) {
                    dynamicMenuButton(title: "menu.wordlist", icon: "character.book.closed.fill", color: .purple, width: buttonWidth, height: idealButtonHeight)
                }
                
                NavigationLink(destination: GrammarPracticeView()) {
                    dynamicMenuButton(title: "menu.grammar", icon: "graduationcap.fill", color: .red, width: buttonWidth, height: idealButtonHeight)
                }
                
                if storeManager.isSubscribed {
                    NavigationLink(destination: PracticeWordView()) {
                        dynamicMenuButton(title: "menu.writing", icon: "pencil", color: .orange, width: buttonWidth, height: idealButtonHeight)
                    }
                } else {
                    Button(action: { showPurchaseView = true }) {
                        dynamicMenuButton(title: "menu.writing", icon: "pencil.and.outline", color: .orange, width: buttonWidth, height: idealButtonHeight)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
        .frame(width: width, height: height)
    }
    
    // MARK: - Menu Button
    private func dynamicMenuButton(title: String, icon: String, color: Color, width: CGFloat, height: CGFloat) -> some View {
        let safeWidth = max(width, 1)
        let safeHeight = max(height, 1)
        
        return HStack(spacing: safeWidth * 0.04) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(
                    width: max(1, min(safeHeight * 0.6, safeWidth * 0.12)),
                    height: max(1, min(safeHeight * 0.6, safeWidth * 0.12))
                )
                .foregroundColor(color)
            
            Text(LocalizedStringKey(title))
                .font(.system(size: max(1, min(safeHeight * 0.45, safeWidth * 0.055)), weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: safeWidth, height: safeHeight)
        .background(colorScheme == .dark ? Color(white: 0.25) : .white)
        .cornerRadius(safeHeight * 0.2)
        .shadow(
            color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.15),
            radius: safeWidth * 0.01,
            x: 0,
            y: safeWidth * 0.008
        )
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95)
    }
}
