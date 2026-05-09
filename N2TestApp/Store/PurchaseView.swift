import SwiftUI
import StoreKit

// MARK: - PurchaseView

struct PurchaseView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedPlan: SubscriptionType = .yearly
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isPurchasing = false
    @State private var headerAppeared = false
    @State private var featuresAppeared = false
    @State private var plansAppeared = false

    // MARK: - Policy URLs
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://doc-hosting.flycricket.io/n2-test-light-privacy-policy/3f91b010-e8ef-4bdc-a3b1-e674a273d8a7/privacy")!

    // MARK: - Savings calculation
    private var savingsPercent: Int? {
        guard
            let monthly = storeManager.monthlyProduct?.price,
            let yearly  = storeManager.yearlyProduct?.price,
            monthly > 0
        else { return nil }
        let annualMonthly = monthly * 12
        let savings = (annualMonthly - yearly) / annualMonthly * 100
        let savingsDouble = NSDecimalNumber(decimal: savings).doubleValue
        return Int(savingsDouble.rounded())
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case .monthly: return storeManager.monthlyProduct
        case .yearly:  return storeManager.yearlyProduct
        default:       return nil
        }
    }

    var body: some View {
        ZStack {
            // 배경 그라디언트
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.08, blue: 0.20),
                    Color(red: 0.05, green: 0.12, blue: 0.30)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 배경 블러 원형 장식
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: -80, y: -200)
                Circle()
                    .fill(Color.indigo.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: 100, y: 100)
            }

            VStack(spacing: 0) {
                // 닫기 버튼
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // MARK: 헤더
                        headerSection

                        // MARK: 기능 목록
                        featuresSection

                        // MARK: 플랜 선택
                        planPickerSection

                        // MARK: CTA 버튼
                        ctaSection

                        // MARK: 복원 & 약관
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            Task { await storeManager.requestProducts() }
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.1)) { headerAppeared = true }
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.3)) { featuresAppeared = true }
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.5)) { plansAppeared = true }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: 80, height: 80)
                Image(systemName: "star.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: 8) {
                Text("purchase.header.title")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("purchase.header.subtitle")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
        .opacity(headerAppeared ? 1 : 0)
        .offset(y: headerAppeared ? 0 : 20)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(spacing: 0) {
            FeatureRowV2(icon: "xmark.circle.fill",
                         iconColor: Color(red: 1, green: 0.42, blue: 0.42),
                         title: String(localized: "feature.remove_ads.title"),
                         subtitle: String(localized: "feature.remove_ads.subtitle"))
            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 16)
            FeatureRowV2(icon: "mic.fill",
                         iconColor: Color(red: 0.42, green: 0.78, blue: 1),
                         title: String(localized: "feature.unlimited_recording.title"),
                         subtitle: String(localized: "feature.unlimited_recording.subtitle"))
            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 16)
            FeatureRowV2(icon: "doc.text.fill",
                         iconColor: Color(red: 0.72, green: 0.56, blue: 1),
                         title: String(localized: "feature.full_script.title"),
                         subtitle: String(localized: "feature.full_script.subtitle"))
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .opacity(featuresAppeared ? 1 : 0)
        .offset(y: featuresAppeared ? 0 : 20)
    }

    // MARK: - Plan Picker Section

    private var planPickerSection: some View {
        VStack(spacing: 12) {
            // 플랜 카드 선택
            HStack(spacing: 12) {
                // 월간
                PlanCard(
                    period: String(localized: "plan.monthly"),
                    priceText: storeManager.monthlyProduct?.displayPrice ?? "...",
                    perPeriod: String(localized: "plan.per_month"),
                    badgeText: nil,
                    isSelected: selectedPlan == .monthly,
                    isLoading: storeManager.isLoading && storeManager.monthlyProduct == nil
                ) {
                    withAnimation(.spring(duration: 0.3)) { selectedPlan = .monthly }
                }

                // 연간
                PlanCard(
                    period: String(localized: "plan.yearly"),
                    priceText: storeManager.yearlyProduct?.displayPrice ?? "...",
                    perPeriod: String(localized: "plan.per_year"),
                    badgeText: savingsPercent.map { value in "\(String(localized: "plan.save_percent", defaultValue: "Save")) \(value)%" },
                    isSelected: selectedPlan == .yearly,
                    isLoading: storeManager.isLoading && storeManager.yearlyProduct == nil
                ) {
                    withAnimation(.spring(duration: 0.3)) { selectedPlan = .yearly }
                }
            }
        }
        .opacity(plansAppeared ? 1 : 0)
        .offset(y: plansAppeared ? 0 : 20)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 14) {
            // 이미 구독 중인지 확인
            let isAlreadySubscribed = storeManager.activeSubscriptionType == selectedPlan

            Button(action: {
                guard !isAlreadySubscribed else { return }
                Task { await handlePurchase() }
            }) {
                ZStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else if isAlreadySubscribed {
                        Label(String(localized: "purchase.cta.currently_subscribed"), systemImage: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Text(selectedPlan == .yearly ? String(localized: "purchase.cta.start_yearly") : String(localized: "purchase.cta.start_monthly"))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        if isAlreadySubscribed {
                            LinearGradient(colors: [.green.opacity(0.7), .green.opacity(0.5)],
                                           startPoint: .leading, endPoint: .trailing)
                        } else {
                            LinearGradient(colors: [Color(red: 0.28, green: 0.56, blue: 1),
                                                    Color(red: 0.48, green: 0.36, blue: 1)],
                                           startPoint: .leading, endPoint: .trailing)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)
                .scaleEffect(isPurchasing ? 0.97 : 1.0)
                .animation(.spring(duration: 0.2), value: isPurchasing)
            }
            .disabled(isPurchasing || isAlreadySubscribed)

            // 구독 안내 소문자
            Text(selectedPlan == .yearly
                 ? String(localized: "purchase.cta.helper.yearly")
                 : String(localized: "purchase.cta.helper.monthly"))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
        }
        .opacity(plansAppeared ? 1 : 0)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 20) {
            Button(action: {
                Task { await handleRestore() }
            }) {
                HStack(spacing: 5) {
                    if storeManager.isLoading {
                        ProgressView().scaleEffect(0.7).tint(.white)
                    }
                    Text("purchase.footer.restore")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .disabled(storeManager.isLoading)

            Text("·").foregroundColor(.white.opacity(0.25))

            Button(action: { openURL(termsURL) }) {
                Text("purchase.footer.terms")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.45))
            }

            Text("·").foregroundColor(.white.opacity(0.25))

            Button(action: { openURL(privacyURL) }) {
                Text("purchase.footer.privacy")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
    }

    // MARK: - Actions

    @MainActor
    private func handlePurchase() async {
        withAnimation { isPurchasing = true }
        defer { withAnimation { isPurchasing = false } }
        do {
            switch selectedPlan {
            case .monthly: _ = try await storeManager.purchaseMonthlySubscription()
            case .yearly:  _ = try await storeManager.purchaseYearlySubscription()
            default: break
            }
        } catch {
            alertTitle   = String(localized: "purchase.alert.failed.title")
            alertMessage = error.localizedDescription
            showAlert    = true
        }
    }

    @MainActor
    private func handleRestore() async {
        do {
            try await storeManager.restorePurchases()
            alertTitle   = String(localized: "purchase.alert.restore_complete.title")
            alertMessage = storeManager.isPremium
                ? String(localized: "purchase.alert.restore_complete.message.restored")
                : String(localized: "purchase.alert.restore_complete.message.none")
            showAlert = true
        } catch {
            alertTitle   = String(localized: "purchase.alert.restore_failed.title")
            alertMessage = error.localizedDescription
            showAlert    = true
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let period: String
    let priceText: String
    let perPeriod: String
    let badgeText: String?
    let isSelected: Bool
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 뱃지
                if let badge = badgeText {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [.orange, .pink],
                                                     startPoint: .leading,
                                                     endPoint: .trailing))
                        )
                } else {
                    // 높이 맞추기용 투명 placeholder
                    Text("　")
                        .font(.system(size: 11))
                        .padding(.vertical, 4)
                        .opacity(0)
                }

                Text(period)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))

                if isLoading {
                    ShimmerLine()
                        .frame(height: 22)
                        .padding(.horizontal, 16)
                } else {
                    Text(priceText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                }

                Text(perPeriod)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.6) : .white.opacity(0.3))
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected
                          ? Color.white.opacity(0.14)
                          : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected
                        ? LinearGradient(colors: [Color(red: 0.28, green: 0.56, blue: 1),
                                                  Color(red: 0.48, green: 0.36, blue: 1)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.1),
                                                  Color.white.opacity(0.1)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.3) : .clear,
                    radius: 12, x: 0, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Row V2

struct FeatureRowV2: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Shimmer Loading Line

struct ShimmerLine: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.2), location: 0.4),
                                .init(color: .white.opacity(0.25), location: 0.5),
                                .init(color: .white.opacity(0.2), location: 0.6),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .init(x: phase, y: 0),
                            endPoint: .init(x: phase + 1, y: 0)
                        )
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

