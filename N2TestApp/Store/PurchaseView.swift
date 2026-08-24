import SwiftUI
import StoreKit

struct PurchaseView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var selectedPlan: SubscriptionType = .yearly
    @State private var animateHeader = false
    @State private var animateCards = false
    @State private var animatePlans = false
    @State private var isPurchasing = false
    @State private var isEligibleForFreeTrial = false

    // 연간 절약률 계산 (월 $2.99 x 12 = $35.88, 연 $19.99)
    private var savingsPercent: Int {
        guard
            let monthly = storeManager.monthlyProduct?.price,
            let yearly = storeManager.yearlyProduct?.price
        else { return 44 }
        let annualMonthly = monthly * 12
        guard annualMonthly > 0 else { return 44 }
        let savings = (annualMonthly - yearly) / annualMonthly * 100
        return Int(truncating: savings as NSDecimalNumber)
    }

    private var monthlyEquivalentFromYearly: String {
        guard let yearly = storeManager.yearlyProduct?.price else { return "$1.67" }
        let perMonth = yearly / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = storeManager.yearlyProduct?.priceFormatStyle.currencyCode ?? "USD"
        return formatter.string(from: perMonth as NSDecimalNumber) ?? "$1.67"
    }

    var body: some View {
        ZStack {
            // 배경 그라디언트
            backgroundGradient
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

                        // 헤더
                        headerSection

                        // 기능 혜택
                        featuresSection

                        // 소셜 프루프
                        socialProofBanner

                        // 플랜 선택 카드
                        planSelectionSection

                        // 구독 CTA 버튼
                        ctaButton

                        // 보조 정보
                        footerSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            if storeManager.activeSubscriptionType != .none {
                selectedPlan = storeManager.activeSubscriptionType
            }
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.1)) { animateHeader = true }
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.3)) { animateCards = true }
            withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.5)) { animatePlans = true }
        }
        .task(id: selectedPlan) {
            await refreshFreeTrialEligibility()
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.13, blue: 0.32),
                Color(red: 0.05, green: 0.08, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .shadow(color: .orange.opacity(0.5), radius: 20, x: 0, y: 8)
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            Text(LocalizedStringKey("purchase.title"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(LocalizedStringKey("purchase.subtitle"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .opacity(animateHeader ? 1 : 0)
        .offset(y: animateHeader ? 0 : 20)
    }

    // MARK: - Features
    private var featuresSection: some View {
        VStack(spacing: 0) {
            PremiumFeatureRow(
                icon: "nosign",
                iconColor: .red,
                title: LocalizedStringKey("purchase.feature.remove_ads.title"),
                description: LocalizedStringKey("purchase.feature.remove_ads.description")
            )
            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 16)
            
            PremiumFeatureRow(
                icon: "globe.americas.fill",
                iconColor: .blue,
                title: LocalizedStringKey("purchase.feature.reading_explanations.title"),
                description: LocalizedStringKey("purchase.feature.reading_explanations.description")
            )
            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 16)
            
            PremiumFeatureRow(
                icon: "doc.text.fill",
                iconColor: .cyan,
                title: LocalizedStringKey("purchase.feature.transcript.title"),
                description: LocalizedStringKey("purchase.feature.transcript.description")
            )
            Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 16)
            
            // 🌟 새로 추가된 오디오 배속 조절 기능
            PremiumFeatureRow(
                icon: "speedometer",
                iconColor: .green,
                title: LocalizedStringKey("purchase.feature.playback_speed.title"),
                description: LocalizedStringKey("purchase.feature.playback_speed.description")
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
    }

    // MARK: - Social Proof
    private var socialProofBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 14))
                .foregroundColor(.yellow)
            Text(LocalizedStringKey("purchase.social_proof"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .opacity(animateCards ? 1 : 0)
    }

    // MARK: - Plan Selection
    private var planSelectionSection: some View {
        HStack(spacing: 12) {
            // 연간 플랜 (추천)
            PlanCard(
                isSelected: selectedPlan == .yearly,
                badge: "\(savingsPercent)% OFF",
                badgeColor: .orange,
                title: LocalizedStringKey("purchase.plan.yearly"),
                priceMain: storeManager.yearlyProduct?.displayPrice ?? "$19.99",
                priceSub: "\(monthlyEquivalentFromYearly) / mo",
                tag: LocalizedStringKey("purchase.plan.recommended"),
                isSubscribed: storeManager.activeSubscriptionType == .yearly
            ) {
                withAnimation(.spring(duration: 0.3)) { selectedPlan = .yearly }
            }

            // 월간 플랜
            PlanCard(
                isSelected: selectedPlan == .monthly,
                badge: nil,
                badgeColor: .blue,
                title: LocalizedStringKey("purchase.plan.monthly"),
                priceMain: storeManager.monthlyProduct?.displayPrice ?? "$2.99",
                priceSub: LocalizedStringKey("purchase.plan.monthly_sub"),
                tag: nil,
                isSubscribed: storeManager.activeSubscriptionType == .monthly
            ) {
                withAnimation(.spring(duration: 0.3)) { selectedPlan = .monthly }
            }
        }
        .opacity(animatePlans ? 1 : 0)
        .offset(y: animatePlans ? 0 : 20)
    }

    // MARK: - CTA Button
    private var ctaButton: some View {
        VStack(spacing: 10) {
            Button(action: {
                Task { await startPurchase() }
            }) {
                ZStack {
                    if isPurchasing || storeManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else if isAlreadySubscribed {
                        Label(NSLocalizedString("purchase.subscribed", comment: ""), systemImage: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    } else {
                        Text(ctaTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
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
            .disabled(isPurchasing || storeManager.isLoading || isAlreadySubscribed)

            if selectedPlan == .yearly {
                Text(isEligibleForFreeTrial
                     ? LocalizedStringKey("purchase.free_trial_disclosure")
                     : LocalizedStringKey("purchase.cancel_anytime"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .opacity(animatePlans ? 1 : 0)
    }

    private var ctaTitle: String {
        if isAlreadySubscribed {
            return NSLocalizedString("purchase.subscribed", comment: "")
        }
        if isEligibleForFreeTrial {
            return NSLocalizedString("purchase.cta_free_trial", comment: "")
        }
        return NSLocalizedString("purchase.cta_subscribe", comment: "")
    }

    private var isAlreadySubscribed: Bool {
        storeManager.activeSubscriptionType == selectedPlan
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(action: { Task { await restorePurchases() } }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                        Text(LocalizedStringKey("purchase.restore"))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.45))
                }
                .disabled(storeManager.isLoading)

                Text("·").foregroundColor(.white.opacity(0.25))

                Link(LocalizedStringKey("purchase.terms"),
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)

                Text("·").foregroundColor(.white.opacity(0.25))

                Link(LocalizedStringKey("purchase.privacy"),
                     destination: URL(string: "https://doc-hosting.flycricket.io/n2-test-light-privacy-policy/3f91b010-e8ef-4bdc-a3b1-e674a273d8a7/privacy")!)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }

            Text(LocalizedStringKey("purchase.subscription_notice"))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private func refreshFreeTrialEligibility() async {
        // 현재 구독 중이거나 과거 구독 이력 있는 사용자 → 무료 체험 제외
        guard !storeManager.isSubscribed, !storeManager.hasEverSubscribed else {
            isEligibleForFreeTrial = false
            return
        }
        guard let product = selectedPlan == .yearly ? storeManager.yearlyProduct : storeManager.monthlyProduct,
              let subscription = product.subscription else {
            isEligibleForFreeTrial = false
            return
        }
        isEligibleForFreeTrial = await subscription.isEligibleForIntroOffer
    }

    private func startPurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if selectedPlan == .yearly {
                _ = try await storeManager.purchaseYearlySubscription()
            } else {
                _ = try await storeManager.purchaseMonthlySubscription()
            }
            
            // ✅ 결제 성공 시 뷰 닫고 자동으로 원래 화면 복귀
            dismiss()
            
        } catch {
            alertTitle = NSLocalizedString("purchase.alert.failed.title", comment: "")
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func restorePurchases() async {
        do {
            try await storeManager.restorePurchases()
            
            if storeManager.isSubscribed {
                // ✅ 복원 성공 시 바로 뷰 닫고 자동으로 원래 화면 복귀
                dismiss()
            } else {
                // 복원할 항목이 없는 경우에만 알림 띄우기
                alertTitle = NSLocalizedString("purchase.alert.restore.title", comment: "")
                alertMessage = NSLocalizedString("purchase.alert.restore.none", comment: "")
                showAlert = true
            }
        } catch {
            alertTitle = NSLocalizedString("purchase.alert.restore_failed.title", comment: "")
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let isSelected: Bool
    let badge: String?
    let badgeColor: Color
    let title: LocalizedStringKey
    let priceMain: String
    let priceSub: Any // String 또는 LocalizedStringKey
    let tag: LocalizedStringKey?
    let isSubscribed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 뱃지
                if let badge = badge {
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
                    Text(" ")
                        .font(.system(size: 11))
                        .padding(.vertical, 4)
                        .opacity(0)
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))

                Text(isSubscribed ? NSLocalizedString("purchase.subscribed", comment: "") : priceMain)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(isSubscribed ? .green : (isSelected ? .white : .white.opacity(0.5)))

                Group {
                    if let sub = priceSub as? String {
                        Text(sub)
                    } else if let sub = priceSub as? LocalizedStringKey {
                        Text(sub)
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .white.opacity(0.6) : .white.opacity(0.3))
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
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
            .shadow(color: isSelected ? Color.blue.opacity(0.3) : .clear, radius: 12, x: 0, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Feature Row
struct PremiumFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let description: LocalizedStringKey

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
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
