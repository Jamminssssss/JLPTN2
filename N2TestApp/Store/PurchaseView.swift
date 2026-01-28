import SwiftUI
import StoreKit

struct PurchaseView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // 헤더
                    VStack(spacing: 16) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("purchase.title")
                            .font(.largeTitle).bold()
                    }
                    .padding(.top, 20)
                    
                    // 구독 안내 문구
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "info.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        Text("purchase.subscription_notice")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // 기능 설명
                    VStack(spacing: 20) {
                        FeatureRow(icon: "checkmark.circle.fill",
                                   title: "purchase.feature.remove_ads.title",
                                   description: "purchase.feature.remove_ads.description")
                        
                        FeatureRow(icon: "mic.fill",
                                   title: "purchase.feature.recording.title",
                                   description: "purchase.feature.recording.description")
                        
                        FeatureRow(icon: "doc.text.fill",
                                   title: "purchase.feature.transcript.title",
                                   description: "purchase.feature.transcript.description")
                    }
                    .padding(.horizontal, 20)
                    
                    // 구독 버튼
                    VStack(spacing: 16) {
                        // 월 구독
                        let monthlyText = storeManager.monthlyProduct?.displayPrice ?? "Loading..."
                        Button(action: { Task { await purchaseMonthly() } }) {
                            HStack {
                                Image(systemName: "calendar")
                                Text(storeManager.activeSubscriptionType == .monthly ?
                                     LocalizedStringKey("purchase.subscribed") :
                                     LocalizedStringKey("purchase.monthly_subscription \(monthlyText)"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(storeManager.activeSubscriptionType == .monthly)
                        
                        // 연 구독
                        let yearlyText = storeManager.yearlyProduct?.displayPrice ?? "Loading..."
                        Button(action: { Task { await purchaseYearly() } }) {
                            HStack {
                                Image(systemName: "calendar.badge.checkmark")
                                Text(storeManager.activeSubscriptionType == .yearly ?
                                     LocalizedStringKey("purchase.subscribed") :
                                     LocalizedStringKey("purchase.yearly_subscription \(yearlyText)"))
                                    .fontWeight(.semibold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(storeManager.activeSubscriptionType == .yearly)
                        
                        // 복원 버튼
                        Button(action: { Task { await restorePurchases() } }) {
                            HStack {
                                if storeManager.isLoading { ProgressView().scaleEffect(0.8) }
                                else { Image(systemName: "arrow.clockwise") }
                                Text("purchase.restore")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(storeManager.isLoading)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("purchase.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task { await storeManager.requestProducts() }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("common.close") {}
        } message: { Text(alertMessage) }
    }
    
    // MARK: - Functions
    @MainActor private func purchaseMonthly() async {
        do {
            _ = try await storeManager.purchaseMonthlySubscription()
        } catch {
            alertTitle = NSLocalizedString("purchase.alert.failed.title", comment: "")
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    @MainActor private func purchaseYearly() async {
        do {
            _ = try await storeManager.purchaseYearlySubscription()
        } catch {
            alertTitle = NSLocalizedString("purchase.alert.failed.title", comment: "")
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
    
    @MainActor private func restorePurchases() async {
        do {
            try await storeManager.restorePurchases()
            alertTitle = NSLocalizedString("purchase.alert.restore.title", comment: "")
            alertMessage = storeManager.isPremium ?
                NSLocalizedString("purchase.alert.restore.success", comment: "") :
                NSLocalizedString("purchase.alert.restore.none", comment: "")
            showAlert = true
        } catch {
            alertTitle = NSLocalizedString("purchase.alert.restore_failed.title", comment: "")
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - Supporting Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title)).font(.headline)
                Text(LocalizedStringKey(description)).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(LinearGradient(colors: [.blue, .blue.opacity(0.8)],
                                       startPoint: .top,
                                       endPoint: .bottom))
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue, lineWidth: 1))
            .foregroundColor(.blue)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}
