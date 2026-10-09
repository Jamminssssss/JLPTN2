import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import UIKit

final class FirebaseAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseTelemetry.configure()
        AdRemoteConfig.shared.start()
        return true
    }
}

/// Keeps Firebase initialization and event names in one place.
enum FirebaseTelemetry {
    static func configure() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        Analytics.setUserProperty(Locale.preferredLanguages.first ?? "unknown", forName: "app_language")
        Crashlytics.crashlytics().log("Firebase initialized")

        #if DEBUG
        // Opt-in smoke test only; never included in a release build.
        if ProcessInfo.processInfo.arguments.contains("-N2TestAppCrashlyticsTestCrash") {
            fatalError("JLPT N2 Crashlytics test crash")
        }
        #endif
    }

    static func log(_ event: String, parameters: [String: Any]? = nil) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(event, parameters: parameters)
    }

    static func screen(_ name: String) {
        log(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: name
        ])
    }

    static func record(_ error: Error, operation: String) {
        guard FirebaseApp.app() != nil else { return }
        Crashlytics.crashlytics().record(error: error, userInfo: ["operation": operation])
    }
}
