import Foundation

/// Local defaults and validation for remotely supplied ad settings.
struct AdPolicy: Equatable {
    static let defaults: [String: String] = [
        "ads_enabled": "true",
        "banner_ads_enabled": "true",
        "interstitial_ads_enabled": "true",
        "app_open_ads_enabled": "true",
        "fullscreen_ad_min_interval_seconds": "120"
    ]

    let adsEnabled: Bool
    let bannerAdsEnabled: Bool
    let interstitialAdsEnabled: Bool
    let appOpenAdsEnabled: Bool
    let minimumFullscreenInterval: TimeInterval

    init(values: [String: String] = defaults) {
        func flag(_ key: String) -> Bool {
            switch values[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1": return true
            case "false", "0": return false
            default: return true
            }
        }
        adsEnabled = flag("ads_enabled")
        bannerAdsEnabled = flag("banner_ads_enabled")
        interstitialAdsEnabled = flag("interstitial_ads_enabled")
        appOpenAdsEnabled = flag("app_open_ads_enabled")
        let interval = Double(values["fullscreen_ad_min_interval_seconds"] ?? "") ?? 120
        minimumFullscreenInterval = interval.isFinite && (60...3600).contains(interval) ? interval : 120
    }
}
