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

    @State private var isInitializing = true
    @State private var adTimeoutWorkItem: DispatchWorkItem?

    // 🌟 하단 탭바 컨트롤을 위한 상태 변수
    @State private var isTabBarHidden = false

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
            // MARK: - 하단 탭 뷰 구성 (4개 탭)
            TabView {
                // 1. 문제 탭 (읽기, 듣기)
                examTab
                    .tabItem { Label("문제", systemImage: "doc.text.magnifyingglass") }
                    .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
                
                // 2. 연습 탭 (단어, 문법, 쓰기)
                practiceTab
                    .tabItem { Label("연습", systemImage: "dumbbell") }
                    .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
                
                // 3. 오답노트 탭 (외부 분리된 IncorrectNoteView 호출)
                IncorrectNoteView(isTabBarHidden: $isTabBarHidden)
                    .tabItem { Label("오답노트", systemImage: "note.text") }
                    .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
                
                // 4. 통계 탭
                StatisticsView()
                    .tabItem { Label("통계", systemImage: "chart.pie") }
                    .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
            }
            .accentColor(Color(red: 0.09, green: 0.26, blue: 0.68)) // JLPT 파랑색 테마

            // 앱 오프닝 광고용 배경
            if isInitializing && adControlManager.shouldShowAppOpenAds {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onAppear {
                        setupAdTimeout()
                    }
            }
        }
        .fullScreenCover(isPresented: $showPurchaseView) {
            PurchaseView()
        }
        .onAppear {
            // 앱 실행 시 CloudKit 진행도 복원
            Task { await CloudKitManager.shared.restoreData()
                // 🌟 추가됨: 복원 직후, 내 폰 DB에만 덩그러니 남아있는 오답을 서버로 강제 푸시
                    CloudKitManager.shared.backfillLocalDataToCloud()
            }
            
            if #available(iOS 14, *), !hasRequestedATT {
                hasRequestedATT = true
                requestTrackingPermission()
            }

            Task {
                while storeManager.products.isEmpty && !storeManager.isLoading {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }

                await storeManager.updateCustomerProductStatus()
                try? await Task.sleep(nanoseconds: 500_000_000)

                if !hasShownOpenAdThisSession {
                    if adControlManager.shouldShowAppOpenAds {
                        await adManager.loadAd()
                        if adManager.appOpenAd != nil {
                            adManager.showAdIfAvailable()
                        } else {
                            isInitializing = false
                        }
                    } else {
                        isInitializing = false
                    }
                    hasShownOpenAdThisSession = true
                }
            }
        }
        .onChange(of: adManager.isAdShowing) { _, isShowing in
            if !isShowing && isInitializing {
                cancelAdTimeout()
                isInitializing = false
            }
        }
    }

    // MARK: - 1. 문제 탭 뷰 (Exam Tab)
    
    private var examTab: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    AdaptiveTopBannerView()

                    ZStack {
                        backgroundColor.ignoresSafeArea()

                        GeometryReader { contentGeometry in
                            let width = contentGeometry.size.width
                            let height = contentGeometry.size.height

                            if isLandscape {
                                landscapeLayout(width: width, height: height)
                            } else {
                                portraitLayout(width: width, height: height)
                            }
                        }
                    }

                    AdaptiveBottomBannerView()
                }
            }
        }
    }

    private func portraitLayout(width: CGFloat, height: CGFloat) -> some View {
        let padding: CGFloat = 20
        let spacing: CGFloat = 20

        let buttonWidth = width - padding * 2
        let buttonHeight = (height - padding * 2 - spacing) / 2

        return VStack(spacing: spacing) {
            NavigationLink(destination: ReadingView(isTabBarHidden: $isTabBarHidden)) {
                // 🌟 수정: 카탈로그에 존재하는 "menu.reading" 키 적용
                dynamicMenuButton(title: "menu.reading", icon: "book.fill", color: .blue, width: buttonWidth, height: buttonHeight)
            }

            NavigationLink(destination: ListeningView(isTabBarHidden: $isTabBarHidden)) {
                // 🌟 수정: 카탈로그에 존재하는 "menu.listening" 키 적용
                dynamicMenuButton(title: "menu.listening", icon: "headphones", color: .green, width: buttonWidth, height: buttonHeight)
            }
        }
        .padding(padding)
    }

    private func landscapeLayout(width: CGFloat, height: CGFloat) -> some View {
        let padding: CGFloat = 20
        let spacing: CGFloat = 20

        let buttonWidth = (width - padding * 2 - spacing) / 2
        let buttonHeight = height - padding * 2

        return HStack(spacing: spacing) {
            NavigationLink(destination: ReadingView(isTabBarHidden: $isTabBarHidden)) {
                dynamicMenuButton(title: "menu.reading", icon: "book.fill", color: .blue, width: buttonWidth, height: buttonHeight)
            }

            NavigationLink(destination: ListeningView(isTabBarHidden: $isTabBarHidden)) {
                dynamicMenuButton(title: "menu.listening", icon: "headphones", color: .green, width: buttonWidth, height: buttonHeight)
            }
        }
        .padding(padding)
    }

    // 🌟 수정: title 파라미터 String -> LocalizedStringKey
    private func dynamicMenuButton(title: LocalizedStringKey, icon: String, color: Color, width: CGFloat, height: CGFloat) -> some View {
        let safeWidth = max(0, width)
        let safeHeight = max(0, height)
        let iconSize = max(0, safeHeight * 0.35)
        let spacing = max(0, safeHeight * 0.08)
        let fontSize = max(1, min(safeHeight * 0.15, safeWidth * 0.12))

        return VStack(spacing: spacing) {
            Image(systemName: icon).resizable().scaledToFit().frame(width: iconSize, height: iconSize).foregroundColor(color)
            Text(title)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.5)
        }
        .frame(width: safeWidth, height: safeHeight)
        .background(colorScheme == .dark ? Color(white: 0.25) : .white)
        .cornerRadius(20).shadow(radius: 5)
    }

    // MARK: - 2. 연습 탭 뷰 (Practice Tab)
    
    private var practiceTab: some View {
        NavigationStack {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                
                ZStack {
                    backgroundColor.ignoresSafeArea()
                    
                    if isLandscape {
                        practiceLandscapeLayout(width: width, height: height)
                    } else {
                        practicePortraitLayout(width: width, height: height)
                    }
                }
            }
            .navigationTitle("학습 연습")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func practicePortraitLayout(width: CGFloat, height: CGFloat) -> some View {
        let padding: CGFloat = 20
        let spacing: CGFloat = 16
        
        let cardWidth = width - (padding * 2)
        let cardHeight = (height - (padding * 2) - (spacing * 2)) / 3
        
        return VStack(spacing: spacing) {
            NavigationLink(destination: WordListView().toolbar(.hidden, for: .tabBar)) {
                // 🌟 수정: "menu.wordlist" 키 매핑
                dynamicPracticeCard(title: "menu.wordlist", icon: "character.book.closed", color: .orange, width: cardWidth, height: cardHeight)
            }
            NavigationLink(destination: GrammarPracticeView().toolbar(.hidden, for: .tabBar)) {
                // 🌟 수정: "menu.grammar" 키 매핑
                dynamicPracticeCard(title: "menu.grammar", icon: "graduationcap", color: .purple, width: cardWidth, height: cardHeight)
            }
            NavigationLink(destination: PracticeWordView().toolbar(.hidden, for: .tabBar)) {
                // 🌟 수정: "menu.writing" 키 매핑
                dynamicPracticeCard(title: "menu.writing", icon: "pencil", color: .pink, width: cardWidth, height: cardHeight)
            }
        }
        .padding(padding)
    }

    private func practiceLandscapeLayout(width: CGFloat, height: CGFloat) -> some View {
        let padding: CGFloat = 20
        let spacing: CGFloat = 16
        
        let cardWidth = (width - (padding * 2) - (spacing * 2)) / 3
        let cardHeight = height - (padding * 2)
        
        return HStack(spacing: spacing) {
            NavigationLink(destination: WordListView().toolbar(.hidden, for: .tabBar)) {
                dynamicPracticeCard(title: "menu.wordlist", icon: "character.book.closed", color: .orange, width: cardWidth, height: cardHeight)
            }
            NavigationLink(destination: GrammarPracticeView().toolbar(.hidden, for: .tabBar)) {
                dynamicPracticeCard(title: "menu.grammar", icon: "graduationcap", color: .purple, width: cardWidth, height: cardHeight)
            }
            NavigationLink(destination: PracticeWordView().toolbar(.hidden, for: .tabBar)) {
                dynamicPracticeCard(title: "menu.writing", icon: "pencil", color: .pink, width: cardWidth, height: cardHeight)
            }
        }
        .padding(padding)
    }

    // 🌟 수정: title 파라미터 String -> LocalizedStringKey
    private func dynamicPracticeCard(title: LocalizedStringKey, icon: String, color: Color, width: CGFloat, height: CGFloat) -> some View {
        let safeWidth = max(0, width)
        let safeHeight = max(0, height)
        let isWideCard = safeWidth > safeHeight
        
        return Group {
            if isWideCard {
                HStack(spacing: max(12, safeHeight * 0.12)) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: safeHeight * 0.46, height: safeHeight * 0.46)
                        Image(systemName: icon)
                            .font(.system(size: safeHeight * 0.22, weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    Text(title)
                        .font(.system(size: max(16, min(safeHeight * 0.15, safeWidth * 0.06)), weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: max(14, safeHeight * 0.12), weight: .semibold))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.horizontal, max(16, safeWidth * 0.06))
            } else {
                VStack(spacing: max(10, safeHeight * 0.08)) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: min(safeWidth * 0.5, safeHeight * 0.35), height: min(safeWidth * 0.5, safeHeight * 0.35))
                        Image(systemName: icon)
                            .font(.system(size: min(safeWidth * 0.24, safeHeight * 0.16), weight: .semibold))
                            .foregroundColor(color)
                    }
                    
                    Text(title)
                        .font(.system(size: max(14, min(safeHeight * 0.07, safeWidth * 0.11)), weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(width: safeWidth, height: safeHeight)
        .background(colorScheme == .dark ? Color(white: 0.25) : .white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 8, x: 0, y: 4)
    }

    // MARK: - 공통 Helpers

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95)
    }

    private func setupAdTimeout() {
        cancelAdTimeout()
        let workItem = DispatchWorkItem {
            if isInitializing {
                isInitializing = false
            }
        }
        adTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
    }

    private func cancelAdTimeout() {
        adTimeoutWorkItem?.cancel()
        adTimeoutWorkItem = nil
    }

    private func requestTrackingPermission() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}
