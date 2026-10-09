import Foundation

@MainActor
final class AdRemoteConfig {
    static let shared = AdRemoteConfig()
    var policy = AdPolicy()
}

extension Notification.Name {
    static let adPolicyChanged = Notification.Name("adPolicyChanged")
}


// swiftc N2TestApp/Models/AdPolicy.swift N2TestApp/Views/AppAdManager.swift scripts/FullScreenAdPolicyValidation.swift -o /tmp/full-screen-ad-policy
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
        AdRemoteConfig.shared.policy = AdPolicy(values: ["ads_enabled": "false"])
        precondition(!policy.canPresentFullScreenAd)
        AdRemoteConfig.shared.policy = AdPolicy(values: ["fullscreen_ad_min_interval_seconds": "60"])
        precondition(policy.beginFullScreenAd(.appOpen))
        policy.endFullScreenAd(.appOpen)
        time += 59
        precondition(!policy.canPresentFullScreenAd)
        time += 1
        precondition(policy.canPresentFullScreenAd)
        for invalid in ["nan", "inf", "-1", "0", "59", "3601", "invalid"] {
            precondition(AdPolicy(values: ["fullscreen_ad_min_interval_seconds": invalid]).minimumFullscreenInterval == 120)
        }
        print("PASS: shared app-open/interstitial spacing, format ownership, nested purchase suppression and cooldown after purchase dismissal")
    }
}
