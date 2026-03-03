import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

// MARK: - Analytics Service
// Centralized wrapper around Firebase Analytics.
// Uses #if canImport(FirebaseAnalytics) so the project compiles
// even before the Firebase SDK is added via SPM.

public final class AnalyticsService {
    public static let shared = AnalyticsService()

    private init() {}

    // MARK: - Configuration

    /// Call once at app launch after FirebaseApp.configure()
    public func configure() {
        #if canImport(FirebaseAnalytics)
        print("[Analytics] Firebase Analytics configured")
        #else
        print("[Analytics] Firebase SDK not available — events will be logged to console only")
        #endif
    }

    // MARK: - Event Logging

    public func log(_ event: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event, parameters: parameters)
        #endif

        #if DEBUG
        if let params = parameters, !params.isEmpty {
            print("[Analytics] \(event) | \(params)")
        } else {
            print("[Analytics] \(event)")
        }
        #endif
    }

    // MARK: - Screen View

    public func logScreenView(_ screenName: String) {
        log(AnalyticsEventName.screenView, parameters: [
            AnalyticsParamKey.screenName: screenName,
            AnalyticsParamKey.screenClass: screenName
        ])
    }

    // MARK: - User Properties

    public func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif

        #if DEBUG
        print("[Analytics] UserProperty: \(name) = \(value ?? "nil")")
        #endif
    }

    /// Update all user properties at once (call on app launch and after changes)
    public func updateAllUserProperties(
        scholarCount: Int,
        language: String,
        theme: String? = nil,
        updateInterval: String? = nil,
        icloudSyncEnabled: Bool? = nil,
        autoUpdateEnabled: Bool? = nil
    ) {
        setUserProperty(String(scholarCount), forName: AnalyticsUserProperty.scholarCount)
        setUserProperty(language, forName: AnalyticsUserProperty.appLanguage)

        if let theme = theme {
            setUserProperty(theme, forName: AnalyticsUserProperty.appTheme)
        }
        if let interval = updateInterval {
            setUserProperty(interval, forName: AnalyticsUserProperty.updateInterval)
        }
        if let icloud = icloudSyncEnabled {
            setUserProperty(icloud ? "true" : "false", forName: AnalyticsUserProperty.icloudSyncEnabled)
        }
        if let autoUpdate = autoUpdateEnabled {
            setUserProperty(autoUpdate ? "true" : "false", forName: AnalyticsUserProperty.autoUpdateEnabled)
        }

        #if os(iOS)
        setUserProperty("ios", forName: AnalyticsUserProperty.platform)
        #elseif os(macOS)
        setUserProperty("macos", forName: AnalyticsUserProperty.platform)
        #endif

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            setUserProperty(version, forName: AnalyticsUserProperty.appVersion)
        }
    }

    // MARK: - Widget Event Relay (iOS)

    private let widgetEventKey = "PendingAnalyticsEvents"

    /// Called from widget extension to queue an event for the main app
    public func relayWidgetEvent(_ event: String, parameters: [String: String]? = nil) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        var pending = defaults.array(forKey: widgetEventKey) as? [[String: Any]] ?? []
        var entry: [String: Any] = ["event": event, "timestamp": Date().timeIntervalSince1970]
        if let params = parameters {
            entry["parameters"] = params
        }
        pending.append(entry)
        defaults.set(pending, forKey: widgetEventKey)
    }

    /// Called from main app on foreground to forward queued widget events
    public func processWidgetEvents() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        guard let pending = defaults.array(forKey: widgetEventKey) as? [[String: Any]], !pending.isEmpty else { return }

        for entry in pending {
            if let event = entry["event"] as? String {
                let params = entry["parameters"] as? [String: Any]
                log(event, parameters: params)
            }
        }

        defaults.removeObject(forKey: widgetEventKey)
        #if DEBUG
        print("[Analytics] Processed \(pending.count) widget event(s)")
        #endif
    }

    // MARK: - Citation Error Logging

    /// Log a citation fetch error with standardized parameters
    public func logCitationError(_ errorType: String, statusCode: Int? = nil) {
        var params: [String: Any] = [AnalyticsParamKey.errorType: errorType]
        if let code = statusCode {
            params[AnalyticsParamKey.statusCode] = code
        }
        log(AnalyticsEventName.citationRefreshError, parameters: params)
    }
}

// MARK: - SwiftUI Screen Tracking Modifier
#if canImport(SwiftUI)
struct AnalyticsScreenModifier: ViewModifier {
    let screenName: String

    func body(content: Content) -> some View {
        content.onAppear {
            AnalyticsService.shared.logScreenView(screenName)
        }
    }
}

extension View {
    /// Track screen view in Firebase Analytics
    func analyticsScreen(_ name: String) -> some View {
        modifier(AnalyticsScreenModifier(screenName: name))
    }
}
#endif
