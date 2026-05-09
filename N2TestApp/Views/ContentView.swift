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
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            NavigationLink(destination: WordListView()) {
                                Label("단어장", systemImage: "character.book.closed")
                            }

                            NavigationLink(destination: GrammarPracticeView()) {
                                Label("문법 연습", systemImage: "graduationcap")
                            }

                            NavigationLink(destination: PracticeWordView()) {
                                Label("쓰기 연습", systemImage: "pencil")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                        }
                    }
                }
            }

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

    // MARK: - Layout

    private func portraitLayout(width: CGFloat, height: CGFloat) -> some View {
        let padding: CGFloat = 20
        let spacing: CGFloat = 20

        let buttonWidth = width - padding * 2
        let buttonHeight = (height - padding * 2 - spacing) / 2

        return VStack(spacing: spacing) {

            NavigationLink(destination: ReadingView(isTabBarHidden: .constant(false))) {
                dynamicMenuButton(
                    title: "menu.reading",
                    icon: "book.fill",
                    color: .blue,
                    width: buttonWidth,
                    height: buttonHeight
                )
            }

            NavigationLink(destination: ListeningView(isTabBarHidden: .constant(false))) {
                dynamicMenuButton(
                    title: "menu.listening",
                    icon: "headphones",
                    color: .green,
                    width: buttonWidth,
                    height: buttonHeight
                )
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

            NavigationLink(destination: ReadingView(isTabBarHidden: .constant(false))) {
                dynamicMenuButton(
                    title: "menu.reading",
                    icon: "book.fill",
                    color: .blue,
                    width: buttonWidth,
                    height: buttonHeight
                )
            }

            NavigationLink(destination: ListeningView(isTabBarHidden: .constant(false))) {
                dynamicMenuButton(
                    title: "menu.listening",
                    icon: "headphones",
                    color: .green,
                    width: buttonWidth,
                    height: buttonHeight
                )
            }
        }
        .padding(padding)
    }

    // MARK: - Button

    private func dynamicMenuButton(title: String, icon: String, color: Color, width: CGFloat, height: CGFloat) -> some View {
        let safeWidth = max(0, width)
        let safeHeight = max(0, height)
        let iconSize = max(0, safeHeight * 0.35)
        let spacing = max(0, safeHeight * 0.08)
        let fontSize = max(1, min(safeHeight * 0.15, safeWidth * 0.12))

        return VStack(spacing: spacing) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(color)

            Text(LocalizedStringKey(title))
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
        }
        .frame(width: safeWidth, height: safeHeight)
        .background(colorScheme == .dark ? Color(white: 0.25) : .white)
        .cornerRadius(20)
        .shadow(radius: 5)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95)
    }
    // MARK: - Ads

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

    // MARK: - ATT

    private func requestTrackingPermission() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}
