import Foundation

struct AdConfig {

    /// Info.plist에서 값 읽기 (nil 허용)
    private static func value(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    // MARK: - App ID (Google이 요구하는 필수 키)
    static let appID: String? = {
        value(for: "GADApplicationIdentifier")
    }()

    // MARK: - Ad Unit IDs (Release에서는 fallback 없음)
    static let appOpenID: String? = {
        value(for: "AD_APP_OPEN_ID")
    }()

    static let bannerTopID: String? = {
        value(for: "AD_BANNER_TOP_ID")
    }()

    static let bannerBottomID: String? = {
        value(for: "AD_BANNER_BOTTOM_ID")
    }()

    static let interstitialID: String? = {
        value(for: "AD_INTERSTITIAL_ID")
    }()
}
