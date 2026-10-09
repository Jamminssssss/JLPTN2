# JLPT N2 Firebase / AdMob

This app uses its own `N2TestApp/GoogleService-Info.plist` for Firebase project
`jlpt-n2-test` and bundle ID `org.reactjs.native.example.N2TestApp`.
The existing N2 production AdMob IDs are preserved; Debug uses Google test IDs.
Firebase SDK 13.0.0 matches the TopikOne reference project.

## Console setup

1. In Firebase project settings → Integrations, enable Google Analytics.
2. In AdMob → Settings → Linked services, connect JLPT N2 TEST to the matching
   Firebase iOS app. Enable impression-level ad revenue in AdMob for revenue export.
3. Optional: publish these Remote Config parameters. Without a published template,
   or on a first offline launch, the app uses these defaults:

- `ads_enabled`: Boolean, `true`
- `banner_ads_enabled`: Boolean, `true`
- `interstitial_ads_enabled`: Boolean, `true`
- `app_open_ads_enabled`: Boolean, `true`
- `fullscreen_ad_min_interval_seconds`: Number, `120`

The interval accepts 60–3600 seconds; invalid values fall back to 120.
Subscription entitlements continue to suppress advertising.
Release fetches have a one-hour minimum interval, and real-time updates activate
published changes while the app runs. Cached settings survive offline launches.

## Verification in Xcode

Resolve Swift packages and build the N2TestApp scheme. Confirm
`GoogleService-Info.plist` is present in the built app's resources.
For Analytics DebugView, use the launch argument `-FIRDebugEnabled`.
To test Crashlytics in a Debug build, opt in with
`-N2TestAppCrashlyticsTestCrash`; launch without the debugger attached, then remove
the argument and relaunch to upload the crash. This intentional crash is excluded
from Release builds. The symbol upload phase skips simulator builds.

Analytics records reading/listening screen views, study starts/completions,
subscription screen views, and subscription purchase outcomes. Crashlytics records
product loading and purchase errors.

## Standalone ad checks

```sh
swiftc N2TestApp/Models/AdPolicy.swift N2TestApp/Views/AppAdManager.swift scripts/FullScreenAdPolicyValidation.swift -o /tmp/n2-fullscreen-policy
/tmp/n2-fullscreen-policy
swiftc N2TestApp/Models/AdPolicy.swift N2TestApp/Store/AdControlManager.swift scripts/AdPolicyValidation.swift -o /tmp/n2-ad-policy
/tmp/n2-ad-policy
```

Official setup: https://firebase.google.com/docs/admob/ios/quick-start
Linking: https://support.google.com/admob/answer/6383165
