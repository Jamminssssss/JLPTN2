import Combine
import Foundation
import FirebaseCore
import FirebaseRemoteConfig

@MainActor
final class AdRemoteConfig: ObservableObject {
    static let shared = AdRemoteConfig()
    @Published private(set) var policy = AdPolicy()
    private var config: RemoteConfig?
    private var updateListener: ConfigUpdateListenerRegistration?
    private var isFetching = false

    private init() {}

    func start() {
        guard config == nil, FirebaseApp.app() != nil else { return }
        let remote = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        settings.fetchTimeout = 10
        remote.configSettings = settings
        remote.setDefaults(AdPolicy.defaults.mapValues { $0 as NSString })
        config = remote
        applyActiveValues() // Uses previously activated values even when offline.
        Task { await refresh() }
        updateListener = remote.addOnConfigUpdateListener { [weak self] update, error in
            guard error == nil, let update,
                  !update.updatedKeys.isDisjoint(with: Set(AdPolicy.defaults.keys)) else { return }
            Task { @MainActor [weak self] in
                guard let self, let config = self.config else { return }
                do {
                    _ = try await config.activate()
                    self.applyActiveValues()
                } catch {
                    // Keep the active cached policy on an activation failure.
                }
            }
        }
    }

    func refresh() async {
        guard let config, !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            _ = try await config.fetchAndActivate()
            applyActiveValues()
        } catch {
            // Offline launches retain cached values, or the 120-second local default.
        }
    }

    private func applyActiveValues() {
        guard let config else { return }
        let values = Dictionary(uniqueKeysWithValues: AdPolicy.defaults.keys.map {
            ($0, config[$0].stringValue)
        })
        let updated = AdPolicy(values: values)
        let changed = updated != policy
        policy = updated
        if changed {
            FirebaseTelemetry.log("ad_policy_applied", parameters: [
                "ads_enabled": updated.adsEnabled ? 1 : 0,
                "interval_seconds": updated.minimumFullscreenInterval
            ])
            NotificationCenter.default.post(name: .adPolicyChanged, object: nil)
        }
    }
}

extension Notification.Name {
    static let adPolicyChanged = Notification.Name("adPolicyChanged")
}
