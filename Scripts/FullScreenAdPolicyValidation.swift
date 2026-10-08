import Foundation

// swiftc N2TestApp/Views/AppAdManager.swift Scripts/FullScreenAdPolicyValidation.swift -o /tmp/full-screen-ad-policy
@main
enum FullScreenAdPolicyValidation {
    @MainActor
    static func main() {
        var time: TimeInterval = 1000
        let policy = AppAdManager(now: { time })
        precondition(policy.beginFullScreenAd(.appOpen))
        precondition(!policy.beginFullScreenAd(.interstitial))
        // An unrelated or stale callback cannot release another format's lock.
        policy.endFullScreenAd(.interstitial)
        precondition(!policy.canPresentFullScreenAd)
        time += 40
        policy.endFullScreenAd(.appOpen)
        time += 119
        precondition(!policy.canPresentFullScreenAd)
        time += 1
        precondition(policy.beginFullScreenAd(.interstitial))
        time += 30
        policy.endFullScreenAd(.interstitial)
        time += 120
        precondition(policy.canPresentFullScreenAd)
        policy.purchaseScreenDidAppear()
        policy.purchaseScreenDidAppear()
        precondition(!policy.canPresentFullScreenAd)
        policy.purchaseScreenDidDisappear()
        time += 120
        precondition(!policy.canPresentFullScreenAd)
        policy.purchaseScreenDidDisappear()
        precondition(!policy.canPresentFullScreenAd)
        time += 119
        precondition(!policy.canPresentFullScreenAd)
        time += 1
        precondition(policy.canPresentFullScreenAd)
        print("PASS: shared app-open/interstitial spacing, format ownership, nested purchase suppression and cooldown after purchase dismissal")
    }
}
