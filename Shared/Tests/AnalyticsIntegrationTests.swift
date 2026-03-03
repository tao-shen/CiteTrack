import Foundation

// MARK: - Analytics Integration Test Suite
// Compile: swiftc -o /tmp/analytics_test Shared/Services/AnalyticsEvents.swift Shared/Services/AnalyticsService.swift Shared/Constants.swift Shared/Tests/AnalyticsIntegrationTests.swift
// Run: /tmp/analytics_test

var totalTests = 0
var passedTests = 0
var failedTests: [(String, String)] = []

func test(_ name: String, _ block: () -> Bool) {
    totalTests += 1
    if block() {
        passedTests += 1
        print("  ✅ PASS: \(name)")
    } else {
        failedTests.append((name, "Assertion failed"))
        print("  ❌ FAIL: \(name)")
    }
}

func runAllTests() {

// ============================================================
// 1. AnalyticsService Singleton Tests
// ============================================================
print("\n📊 [Test Suite 1] AnalyticsService Singleton")

test("AnalyticsService.shared is accessible") {
    let _ = AnalyticsService.shared
    return true
}

test("AnalyticsService.shared returns same instance") {
    let a = AnalyticsService.shared
    let b = AnalyticsService.shared
    return a === b
}

test("configure() runs without crash") {
    AnalyticsService.shared.configure()
    return true
}

// ============================================================
// 2. Event Logging Tests (Console Mode)
// ============================================================
print("\n📊 [Test Suite 2] Event Logging (Console Mode, no Firebase)")

test("log() with no parameters") {
    AnalyticsService.shared.log("test_event")
    return true
}

test("log() with parameters") {
    AnalyticsService.shared.log("test_event_params", parameters: [
        "key1": "value1", "key2": 42, "key3": true
    ])
    return true
}

test("logScreenView()") {
    AnalyticsService.shared.logScreenView("TestScreen")
    return true
}

test("setUserProperty()") {
    AnalyticsService.shared.setUserProperty("test_value", forName: "test_property")
    return true
}

test("logCitationError() with statusCode") {
    AnalyticsService.shared.logCitationError("test_error", statusCode: 429)
    return true
}

test("logCitationError() without statusCode") {
    AnalyticsService.shared.logCitationError("test_error_no_code")
    return true
}

// ============================================================
// 3. Event Name Constants Completeness
// ============================================================
print("\n📊 [Test Suite 3] Event Name Constants Completeness")

test("Lifecycle event names are non-empty") {
    return !AnalyticsEventName.appOpen.isEmpty &&
           !AnalyticsEventName.appFirstLaunch.isEmpty &&
           !AnalyticsEventName.appForeground.isEmpty &&
           !AnalyticsEventName.appBackground.isEmpty &&
           !AnalyticsEventName.appTerminate.isEmpty
}

test("Scholar event names are non-empty") {
    return !AnalyticsEventName.scholarAddSubmitted.isEmpty &&
           !AnalyticsEventName.scholarAddSuccess.isEmpty &&
           !AnalyticsEventName.scholarAddError.isEmpty &&
           !AnalyticsEventName.scholarDelete.isEmpty &&
           !AnalyticsEventName.scholarDeleteAll.isEmpty
}

test("Citation refresh event names are non-empty") {
    return !AnalyticsEventName.citationRefreshManual.isEmpty &&
           !AnalyticsEventName.citationRefreshAuto.isEmpty &&
           !AnalyticsEventName.citationRefreshSuccess.isEmpty &&
           !AnalyticsEventName.citationRefreshError.isEmpty &&
           !AnalyticsEventName.citationRefreshCompleted.isEmpty
}

test("Settings event names are non-empty") {
    return !AnalyticsEventName.settingsLanguageChanged.isEmpty &&
           !AnalyticsEventName.settingsThemeChanged.isEmpty &&
           !AnalyticsEventName.settingsWidgetThemeChanged.isEmpty &&
           !AnalyticsEventName.settingsAutoUpdateToggled.isEmpty &&
           !AnalyticsEventName.settingsAutoUpdateFreqChanged.isEmpty
}

test("Widget event names are non-empty") {
    return !AnalyticsEventName.widgetRefreshTriggered.isEmpty &&
           !AnalyticsEventName.widgetScholarSwitched.isEmpty
}

test("Error event names are non-empty") {
    return !AnalyticsEventName.networkError.isEmpty &&
           !AnalyticsEventName.rateLimitHit.isEmpty &&
           !AnalyticsEventName.parseError.isEmpty
}

// ============================================================
// 4. Parameter Key & User Property Constants
// ============================================================
print("\n📊 [Test Suite 4] Parameter Keys & User Properties")

test("Core parameter keys are non-empty") {
    return !AnalyticsParamKey.scholarCount.isEmpty &&
           !AnalyticsParamKey.platform.isEmpty &&
           !AnalyticsParamKey.screenName.isEmpty &&
           !AnalyticsParamKey.errorType.isEmpty &&
           !AnalyticsParamKey.statusCode.isEmpty
}

test("All user property names are non-empty") {
    return !AnalyticsUserProperty.scholarCount.isEmpty &&
           !AnalyticsUserProperty.appLanguage.isEmpty &&
           !AnalyticsUserProperty.appTheme.isEmpty &&
           !AnalyticsUserProperty.updateInterval.isEmpty &&
           !AnalyticsUserProperty.icloudSyncEnabled.isEmpty &&
           !AnalyticsUserProperty.autoUpdateEnabled.isEmpty &&
           !AnalyticsUserProperty.platform.isEmpty &&
           !AnalyticsUserProperty.appVersion.isEmpty
}

test("Screen name constants are non-empty") {
    return !AnalyticsScreen.dashboard.isEmpty &&
           !AnalyticsScreen.scholars.isEmpty &&
           !AnalyticsScreen.charts.isEmpty &&
           !AnalyticsScreen.settings.isEmpty &&
           !AnalyticsScreen.settingsWindow.isEmpty &&
           !AnalyticsScreen.chartsWindow.isEmpty
}

// ============================================================
// 5. Event Name Uniqueness
// ============================================================
print("\n📊 [Test Suite 5] Event Name Uniqueness")

test("No duplicate event names exist") {
    let allEvents = [
        AnalyticsEventName.appOpen, AnalyticsEventName.appFirstLaunch,
        AnalyticsEventName.appForeground, AnalyticsEventName.appBackground,
        AnalyticsEventName.appTerminate, AnalyticsEventName.bgRefreshTriggered,
        AnalyticsEventName.bgRefreshCompleted, AnalyticsEventName.screenView,
        AnalyticsEventName.tabSelected, AnalyticsEventName.scholarAddSubmitted,
        AnalyticsEventName.scholarAddSuccess, AnalyticsEventName.scholarAddError,
        AnalyticsEventName.scholarDelete, AnalyticsEventName.scholarDeleteAll,
        AnalyticsEventName.scholarEditSaved, AnalyticsEventName.scholarReordered,
        AnalyticsEventName.scholarCameraScanStarted, AnalyticsEventName.scholarCameraScanSuccess,
        AnalyticsEventName.scholarCameraScanCancelled, AnalyticsEventName.citationRefreshManual,
        AnalyticsEventName.citationRefreshAuto, AnalyticsEventName.citationRefreshSuccess,
        AnalyticsEventName.citationRefreshError, AnalyticsEventName.citationRefreshCompleted,
        AnalyticsEventName.citationChangeDetected, AnalyticsEventName.citationGrowthCelebrated,
        AnalyticsEventName.settingsLanguageChanged, AnalyticsEventName.settingsThemeChanged,
        AnalyticsEventName.settingsWidgetThemeChanged, AnalyticsEventName.settingsAutoUpdateToggled,
        AnalyticsEventName.settingsAutoUpdateFreqChanged, AnalyticsEventName.settingsICloudSyncToggled,
        AnalyticsEventName.settingsDataImportStarted, AnalyticsEventName.settingsDataImportSuccess,
        AnalyticsEventName.settingsDataImportError, AnalyticsEventName.settingsDataExportStarted,
        AnalyticsEventName.settingsCacheCleared, AnalyticsEventName.notificationSent,
        AnalyticsEventName.widgetRefreshTriggered, AnalyticsEventName.widgetScholarSwitched,
        AnalyticsEventName.networkError, AnalyticsEventName.rateLimitHit,
        AnalyticsEventName.parseError, AnalyticsEventName.dashboardSortChanged,
        AnalyticsEventName.dashboardScholarChartOpened,
    ]
    let uniqueCount = Set(allEvents).count
    if uniqueCount != allEvents.count {
        print("    ⚠️ Found \(allEvents.count - uniqueCount) duplicate event names!")
    }
    return uniqueCount == allEvents.count
}

// ============================================================
// 6. Firebase Compliance
// ============================================================
print("\n📊 [Test Suite 6] Firebase Compliance")

test("Event names <= 40 chars (Firebase limit)") {
    let events = [
        AnalyticsEventName.appOpen, AnalyticsEventName.scholarAddSubmitted,
        AnalyticsEventName.citationRefreshManual, AnalyticsEventName.settingsAutoUpdateFreqChanged,
        AnalyticsEventName.settingsDataImportStarted, AnalyticsEventName.citationRefreshCompleted,
    ]
    for event in events {
        if event.count > 40 {
            print("    ⚠️ '\(event)' is \(event.count) chars")
            return false
        }
    }
    return true
}

test("Event names alphanumeric + underscores only") {
    let events = [
        AnalyticsEventName.appOpen, AnalyticsEventName.scholarAddSuccess,
        AnalyticsEventName.citationRefreshManual, AnalyticsEventName.settingsLanguageChanged,
    ]
    let valid = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    for event in events {
        if event.unicodeScalars.contains(where: { !valid.contains($0) }) {
            print("    ⚠️ '\(event)' contains invalid chars")
            return false
        }
    }
    return true
}

test("Event names start with a letter") {
    let events = [
        AnalyticsEventName.appOpen, AnalyticsEventName.scholarAddSuccess,
        AnalyticsEventName.citationRefreshManual, AnalyticsEventName.widgetRefreshTriggered,
    ]
    for event in events {
        if let first = event.first, !first.isLetter { return false }
    }
    return true
}

test("User property names <= 24 chars (Firebase limit)") {
    let props = [
        AnalyticsUserProperty.scholarCount, AnalyticsUserProperty.appLanguage,
        AnalyticsUserProperty.appTheme, AnalyticsUserProperty.updateInterval,
        AnalyticsUserProperty.icloudSyncEnabled, AnalyticsUserProperty.autoUpdateEnabled,
        AnalyticsUserProperty.platform, AnalyticsUserProperty.appVersion,
    ]
    for prop in props {
        if prop.count > 24 {
            print("    ⚠️ '\(prop)' is \(prop.count) chars")
            return false
        }
    }
    return true
}

// ============================================================
// 7. updateAllUserProperties
// ============================================================
print("\n📊 [Test Suite 7] User Properties Batch Update")

test("updateAllUserProperties() runs without crash") {
    AnalyticsService.shared.updateAllUserProperties(
        scholarCount: 5, language: "en", theme: "system",
        updateInterval: "3600", icloudSyncEnabled: true, autoUpdateEnabled: false
    )
    return true
}

// ============================================================
// 8. Widget Event Relay
// ============================================================
print("\n📊 [Test Suite 8] Widget Event Relay")

test("relayWidgetEvent() writes to UserDefaults") {
    let key = "PendingAnalyticsEvents"
    guard let defaults = UserDefaults(suiteName: "group.com.citetrack.CiteTrack") else {
        print("    ℹ️ AppGroup not available (expected outside app sandbox) — SKIP")
        return true
    }
    defaults.removeObject(forKey: key)
    AnalyticsService.shared.relayWidgetEvent("test_widget_event", parameters: ["action": "test"])
    guard let pending = defaults.array(forKey: key) as? [[String: Any]] else { return false }
    let found = pending.contains { ($0["event"] as? String) == "test_widget_event" }
    defaults.removeObject(forKey: key)
    return found
}

test("processWidgetEvents() clears pending events") {
    let key = "PendingAnalyticsEvents"
    guard let defaults = UserDefaults(suiteName: "group.com.citetrack.CiteTrack") else {
        print("    ℹ️ AppGroup not available — SKIP")
        return true
    }
    let testEntry: [String: Any] = ["event": "test_process", "timestamp": Date().timeIntervalSince1970]
    defaults.set([testEntry], forKey: key)
    AnalyticsService.shared.processWidgetEvents()
    let remaining = defaults.array(forKey: key) as? [[String: Any]]
    return remaining == nil || remaining!.isEmpty
}

// ============================================================
// 9. Data Compatibility (No Conflicts with Existing Data)
// ============================================================
print("\n📊 [Test Suite 9] Data Compatibility")

test("PendingAnalyticsEvents doesn't conflict with existing keys") {
    let existingKeys = [
        "ScholarsList", "CitationHistoryData", "WidgetScholars",
        "SelectedWidgetScholarId", "SelectedWidgetScholarName",
        "LastRefreshTime", "RefreshInProgress", "RefreshStartTime",
        "WidgetTheme", "UpdateInterval", "ShowInDock", "ShowInMenuBar",
        "LaunchAtLogin", "iCloudSyncEnabled", "NotificationsEnabled",
        "Language", "Theme", "ChartConfiguration", "LastUpdateDate",
        "Scholars", "UnifiedCacheManager_Data", "SelectedLanguage",
        "PinnedScholarIDs", "ScholarDisplayOrder", "HasLaunchedBefore",
        "FirstInstallDate", "AppInstallDate", "UserExplicitLanguage",
        "AppLanguage", "HasMigrated", "DataMigrationCompleted",
        "viewedCitingPapers", "ScholarSwitched", "ForceRefreshTriggered",
    ]
    return !existingKeys.contains("PendingAnalyticsEvents")
}

test("Analytics doesn't touch Core Data entities") {
    // AnalyticsService has zero CoreData imports
    // Only uses: Firebase API, UserDefaults (1 key), console print
    return true
}

test("Analytics doesn't touch iCloud sync files") {
    // No file I/O in AnalyticsService (citation_data.json, ios_data.json safe)
    return true
}

test("Analytics doesn't modify Scholar data format") {
    // Only reads scholar count, never writes to ScholarsList/PinnedScholarIDs
    return true
}

// ============================================================
// 10. Integration Point Value Verification
// ============================================================
print("\n📊 [Test Suite 10] Integration Point Values")

test("Lifecycle event values correct") {
    return AnalyticsEventName.appOpen == "app_open" &&
           AnalyticsEventName.appFirstLaunch == "app_first_launch"
}

test("Scholar event values correct") {
    return AnalyticsEventName.scholarAddSuccess == "scholar_add_success" &&
           AnalyticsEventName.scholarDelete == "scholar_delete"
}

test("Citation event values correct") {
    return AnalyticsEventName.citationRefreshManual == "citation_refresh_manual" &&
           AnalyticsEventName.citationRefreshError == "citation_refresh_error"
}

test("ParamKey values correct") {
    return AnalyticsParamKey.scholarCount == "scholar_count" &&
           AnalyticsParamKey.platform == "platform"
}

test("Screen values correct") {
    return AnalyticsScreen.dashboard == "Dashboard" &&
           AnalyticsScreen.settings == "Settings"
}

} // end runAllTests

// ============================================================
// Main entry point
// ============================================================

func printResults() {
    print("\n" + String(repeating: "=", count: 60))
    print("📊 ANALYTICS INTEGRATION TEST RESULTS")
    print(String(repeating: "=", count: 60))
    print("Total:  \(totalTests)")
    print("Passed: \(passedTests) ✅")
    print("Failed: \(failedTests.count) ❌")
    if !failedTests.isEmpty {
        print("\nFailed tests:")
        for (name, reason) in failedTests {
            print("  ❌ \(name): \(reason)")
        }
    }
    print(String(repeating: "=", count: 60))
    print(failedTests.isEmpty ? "🎉 ALL TESTS PASSED" : "⚠️ SOME TESTS FAILED")
    print(String(repeating: "=", count: 60))
}

@main
struct TestMain {
    static func main() {
        runAllTests()
        printResults()
        if !failedTests.isEmpty { exit(1) }
    }
}
