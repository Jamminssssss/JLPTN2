import Foundation
import StoreKit

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    private let removeAdsProductID = "org.reactjs.native.example.N2TestApp.adremoval"
    private let monthlySubscriptionID = "org.reactjs.native.example.N2TestApp.sub.monthly"
    private let yearlySubscriptionID = "org.reactjs.native.example.N2TestApp.sub.yearly"
    
    // MARK: - Published

    @Published var products: [Product] = []           // 구독 상품 (월·연)
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubscribed: Bool = false
    @Published var activeSubscriptionType: SubscriptionType = .none

    /// 구독 여부 = 프리미엄 여부
    var isPremium: Bool { isSubscribed }
    var shouldShowAds: Bool { !isSubscribed }

    private var updateListenerTask: Task<Void, Error>? = nil

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }

    deinit { updateListenerTask?.cancel() }

    // MARK: - 잠금 해제 여부
    // set 1은 1~5번 문제가 무료(뷰 레이어에서 처리), 2·3회차는 구독 필요

    func isReadingSetUnlocked(_ set: Int) -> Bool {
        if set == 1 { return true }
        return isSubscribed
    }

    func isListeningSetUnlocked(_ set: Int) -> Bool {
        if set == 1 { return true }
        return isSubscribed
    }

    // MARK: - 상품 로드 (구독 상품만)

    func requestProducts() async {
        do {
            isLoading = true
            defer { isLoading = false }

            let subIDs = [monthlySubscriptionID, yearlySubscriptionID]
            products = try await Product.products(for: subIDs)

            print("📦 구독 상품 \(products.count)개 로드 완료")
        } catch {
            errorMessage = "제품 정보를 불러올 수 없습니다: \(error.localizedDescription)"
            print("❌ 제품 로드 실패: \(error)")
        }
    }

    // MARK: - 구독 구매

    func purchaseMonthlySubscription() async throws -> Transaction? {
        guard activeSubscriptionType != .monthly else { print("⚠️ 이미 월 구독중"); return nil }
        guard let product = products.first(where: { $0.id == monthlySubscriptionID }) else {
            throw StoreError.productNotFound
        }
        return try await purchaseSubscription(product, type: .monthly)
    }

    func purchaseYearlySubscription() async throws -> Transaction? {
        guard activeSubscriptionType != .yearly else { print("⚠️ 이미 연 구독중"); return nil }
        guard let product = products.first(where: { $0.id == yearlySubscriptionID }) else {
            throw StoreError.productNotFound
        }
        return try await purchaseSubscription(product, type: .yearly)
    }

    private func purchaseSubscription(_ product: Product, type: SubscriptionType) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            activeSubscriptionType = type
            print("✅ 구독 구매 성공: \(product.id)")
            return transaction
        case .userCancelled: print("👤 구매 취소"); return nil
        case .pending:       print("⏳ 구매 보류"); return nil
        @unknown default:    return nil
        }
    }

    // MARK: - 복원

    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        try await AppStore.sync()
        await updateCustomerProductStatus()
        print(isSubscribed ? "✅ 구독 복원 완료" : "ℹ️ 복원할 구독 없음")
    }

    // MARK: - 트랜잭션 리스너

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await StoreKitManager.checkVerified(result)
                    await StoreKitManager.shared.updateCustomerProductStatus()
                    await transaction.finish()
                    print("🔄 Transaction 업데이트: \(transaction.productID)")
                } catch {
                    print("❌ Transaction 검증 실패: \(error)")
                }
            }
        }
    }

    // MARK: - 구독 상태 갱신

    func updateCustomerProductStatus() async {
        var purchased: Set<String> = []
        var subscriptionActive = false
        var currentType: SubscriptionType = .none

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try StoreKitManager.checkVerified(result)

                // 자동 갱신 구독
                if transaction.productType == .autoRenewable {
                    let isRevoked  = transaction.revocationDate != nil
                    let notExpired = transaction.expirationDate == nil
                        || (transaction.expirationDate ?? Date()) > Date()
                    if !isRevoked && notExpired {
                        subscriptionActive = true
                        purchased.insert(transaction.productID)
                        if transaction.productID == monthlySubscriptionID      { currentType = .monthly }
                        else if transaction.productID == yearlySubscriptionID  { currentType = .yearly  }
                        print("✅ 활성 구독: \(transaction.productID)")
                    }
                }

                // 레거시 광고 제거 비소모품 → 구독 권한으로 처리
                if transaction.productID == removeAdsProductID {
                    subscriptionActive = true
                    purchased.insert(transaction.productID)
                }

            } catch {
                print("❌ Transaction 검증 실패: \(error)")
            }
        }

        purchasedProducts      = purchased
        isSubscribed           = subscriptionActive
        activeSubscriptionType = currentType

        NotificationCenter.default.post(name: .purchaseStatusChanged, object: nil)
        print("📋 상태 업데이트 완료 — 구독: \(activeSubscriptionType), 프리미엄: \(isSubscribed)")
    }

    // MARK: - 검증

    static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        try StoreKitManager.checkVerified(result)
    }

    // MARK: - 유틸

    func clearError() { errorMessage = nil }

    var monthlyProduct: Product? { products.first(where: { $0.id == monthlySubscriptionID }) }
    var yearlyProduct:  Product? { products.first(where: { $0.id == yearlySubscriptionID  }) }
}

// MARK: - 구독 타입
enum SubscriptionType { case none, monthly, yearly }

// MARK: - 오류
enum StoreError: Error, LocalizedError {
    case failedVerification, productNotFound, purchaseNotAllowed, networkError, unknown
    var errorDescription: String? {
        switch self {
        case .failedVerification:  return "구매 검증에 실패했습니다"
        case .productNotFound:     return "제품을 찾을 수 없습니다"
        case .purchaseNotAllowed:  return "구매가 허용되지 않습니다"
        case .networkError:        return "네트워크 연결을 확인해주세요"
        case .unknown:             return "알 수 없는 오류가 발생했습니다"
        }
    }
}

// MARK: - 알림
extension Notification.Name {
    static let purchaseStatusChanged = Notification.Name("purchaseStatusChanged")
}
