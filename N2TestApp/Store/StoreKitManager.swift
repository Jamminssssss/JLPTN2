import Foundation
import StoreKit

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    private let removeAdsProductID = "org.reactjs.native.example.N2TestApp.adremoval"
    private let monthlySubscriptionID = "org.reactjs.native.example.N2TestApp.sub.monthly"
    private let yearlySubscriptionID = "org.reactjs.native.example.N2TestApp.sub.yearly"
                                      
    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubscribed: Bool = false
    @Published var activeSubscriptionType: SubscriptionType = .none

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

    // MARK: - Load Products
    func requestProducts() async {
        do {
            isLoading = true
            let ids = [monthlySubscriptionID, yearlySubscriptionID]
            let storeProducts = try await Product.products(for: ids)
            self.products = storeProducts
            isLoading = false
            print("📦 제품 로드 완료: \(storeProducts.count)개")
        } catch {
            isLoading = false
            errorMessage = "제품 정보를 불러올 수 없습니다: \(error.localizedDescription)"
            print("❌ 제품 로드 실패: \(error)")
        }
    }

    // MARK: - Purchase Functions
    func purchaseMonthlySubscription() async throws -> Transaction? {
        guard activeSubscriptionType != .monthly else {
            print("⚠️ 이미 월 구독중입니다.")
            return nil
        }
        guard let product = products.first(where: { $0.id == monthlySubscriptionID }) else {
            throw StoreError.productNotFound
        }
        return try await purchase(product, type: .monthly)
    }

    func purchaseYearlySubscription() async throws -> Transaction? {
        guard activeSubscriptionType != .yearly else {
            print("⚠️ 이미 연 구독중입니다.")
            return nil
        }
        guard let product = products.first(where: { $0.id == yearlySubscriptionID }) else {
            throw StoreError.productNotFound
        }
        return try await purchase(product, type: .yearly)
    }

    private func purchase(_ product: Product, type: SubscriptionType) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            print("✅ 구매 성공: \(product.id)")
            activeSubscriptionType = type
            return transaction
        case .userCancelled:
            print("👤 사용자가 구매를 취소했습니다")
            return nil
        case .pending:
            print("⏳ 구매 보류 중")
            return nil
        @unknown default:
            return nil
        }
    }

    // MARK: - Restore
    func restorePurchases() async throws {
        isLoading = true
        defer { isLoading = false }
        try await AppStore.sync()
        await updateCustomerProductStatus()
        print(isSubscribed ? "✅ 구독 복원 완료" : "ℹ️ 복원할 구독 없음")
    }

    // MARK: - Listen for Transaction Updates
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await StoreKitManager.checkVerified(result)
                    await StoreKitManager.shared.updateCustomerProductStatus()
                    await transaction.finish()
                    print("🔄 Transaction 업데이트 처리 완료: \(transaction.productID)")
                } catch {
                    print("❌ Transaction 검증 실패: \(error)")
                }
            }
        }
    }

    // MARK: - Update Subscription Status
    func updateCustomerProductStatus() async {
        var purchased: Set<String> = []
        var subscriptionActive = false
        var currentType: SubscriptionType = .none

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try StoreKitManager.checkVerified(result)

                // 🔹 월/연 구독 체크
                if transaction.productType == .autoRenewable {
                    let isRevoked = transaction.revocationDate != nil
                    let notExpired = transaction.expirationDate == nil || (transaction.expirationDate ?? Date()) > Date()

                    if !isRevoked && notExpired {
                        subscriptionActive = true
                        purchased.insert(transaction.productID)
                        if transaction.productID == monthlySubscriptionID { currentType = .monthly }
                        else if transaction.productID == yearlySubscriptionID { currentType = .yearly }
                        print("✅ 활성 구독: \(transaction.productID)")
                    }
                }

                // 🔹 기존 광고 제거 결제 체크
                if transaction.productID == removeAdsProductID {
                    subscriptionActive = true
                    purchased.insert(transaction.productID)
                    print("✅ 광고 제거 결제 감지: \(transaction.productID)")
                }

            } catch {
                print("❌ Transaction 검증 실패: \(error)")
            }
        }

        purchasedProducts = purchased
        isSubscribed = subscriptionActive
        activeSubscriptionType = currentType

        NotificationCenter.default.post(name: .purchaseStatusChanged, object: nil)
        print("📋 구독 상태 업데이트 완료")
        print("  - 활성 구독: \(activeSubscriptionType)")
    }

    // MARK: - Verification
    static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }

    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        try StoreKitManager.checkVerified(result)
    }

    // MARK: - Utility
    func clearError() { errorMessage = nil }

    var monthlyProduct: Product? { products.first(where: { $0.id == monthlySubscriptionID }) }
    var yearlyProduct: Product? { products.first(where: { $0.id == yearlySubscriptionID }) }
}

// MARK: - Subscription Type Enum
enum SubscriptionType { case none, monthly, yearly }

// MARK: - Store Errors
enum StoreError: Error, LocalizedError {
    case failedVerification, productNotFound, purchaseNotAllowed, networkError, unknown
    var errorDescription: String? {
        switch self {
        case .failedVerification: return "구매 검증에 실패했습니다"
        case .productNotFound: return "제품을 찾을 수 없습니다"
        case .purchaseNotAllowed: return "구매가 허용되지 않습니다"
        case .networkError: return "네트워크 연결을 확인해주세요"
        case .unknown: return "알 수 없는 오류가 발생했습니다"
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let purchaseStatusChanged = Notification.Name("purchaseStatusChanged")
}
