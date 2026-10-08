import Foundation

/// Shared spacing and presentation ownership for every full-screen ad format.
@MainActor
final class AppAdManager {
    enum Format { case interstitial, appOpen }

    static let shared = AppAdManager()
    private let now: () -> TimeInterval
    private let minimumInterval: TimeInterval = 120
    private var lastFinishedAt: TimeInterval?
    private var activeFormat: Format?
    private var purchaseScreens = 0

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
    }

    var canPresentFullScreenAd: Bool {
        guard activeFormat == nil, purchaseScreens == 0 else { return false }
        guard let lastFinishedAt else { return true }
        return now() - lastFinishedAt >= minimumInterval
    }

    func beginFullScreenAd(_ format: Format) -> Bool {
        guard canPresentFullScreenAd else { return false }
        activeFormat = format
        return true
    }

    func endFullScreenAd(_ format: Format) {
        guard activeFormat == format else { return }
        activeFormat = nil
        lastFinishedAt = now()
    }

    func purchaseScreenDidAppear() {
        purchaseScreens += 1
    }

    func purchaseScreenDidDisappear() {
        purchaseScreens = max(0, purchaseScreens - 1)
        // Returning from a purchase screen should resume learning without an ad.
        lastFinishedAt = now()
    }
}
