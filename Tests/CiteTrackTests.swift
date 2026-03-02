#!/usr/bin/env swift
// CiteTrack Comprehensive Test Suite
// Tests all P0, P1, and P2 fixes applied to the codebase
// Run: swift Tests/CiteTrackTests.swift

import Foundation

// MARK: - Test Framework
var totalTests = 0
var passedTests = 0
var failedTests = 0
var testResults: [(name: String, passed: Bool, detail: String)] = []

func test(_ name: String, _ block: () -> Bool, detail: String = "") {
    totalTests += 1
    let passed = block()
    if passed {
        passedTests += 1
        testResults.append((name, true, detail.isEmpty ? "OK" : detail))
    } else {
        failedTests += 1
        testResults.append((name, false, detail.isEmpty ? "FAILED" : detail))
    }
}

// MARK: - File Utilities
func readFile(_ path: String) -> String {
    return (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

func fileExists(_ path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
}

let base = "/Users/tao.shen/google_scholar_plugin"

// ============================================================================
// MARK: - P0-1: Core Data Model Sync Tests
// ============================================================================

print("=== P0-1: Core Data Model Sync ===")

let sharedModel = readFile("\(base)/Shared/CoreData/CitationTrackingModel.xcdatamodeld/CitationTrackingModel.xcdatamodel/contents")
let macOSModel = readFile("\(base)/macOS/Sources/CitationTrackingModel.xcdatamodeld/CitationTrackingModel.xcdatamodel/contents")

test("P0-1a: Shared model has CitingPaperEntity") {
    sharedModel.contains("name=\"CitingPaperEntity\"")
}

test("P0-1b: Shared model has CitingAuthorEntity") {
    sharedModel.contains("name=\"CitingAuthorEntity\"")
}

test("P0-1c: macOS model has CitingPaperEntity") {
    macOSModel.contains("name=\"CitingPaperEntity\"")
}

test("P0-1d: macOS model has CitingAuthorEntity") {
    macOSModel.contains("name=\"CitingAuthorEntity\"")
}

test("P0-1e: Both models have same entity count (3)") {
    let sharedCount = sharedModel.components(separatedBy: "<entity name=").count - 1
    let macOSCount = macOSModel.components(separatedBy: "<entity name=").count - 1
    return sharedCount == 3 && macOSCount == 3
}

test("P0-1f: Model has version identifier") {
    macOSModel.contains("userDefinedModelVersionIdentifier=\"1.0\"")
}

// ============================================================================
// MARK: - P0-2: Thread.sleep() Removal Tests
// ============================================================================

print("\n=== P0-2: Thread.sleep() Removal ===")

let fetchService = readFile("\(base)/Shared/Services/CitationFetchService.swift")

test("P0-2a: No Thread.sleep in CitationFetchService") {
    !fetchService.contains("Thread.sleep(forTimeInterval:")
}

test("P0-2b: Uses asyncAfter for rate limiting") {
    fetchService.contains("DispatchQueue.main.asyncAfter(deadline:")
}

// ============================================================================
// MARK: - P0-3: Unsafe Singleton Fix Tests
// ============================================================================

print("\n=== P0-3: Singleton Thread Safety ===")

let citationManager = readFile("\(base)/Shared/Managers/CitationManager.swift")

test("P0-3a: No nonisolated(unsafe) in CitationManager") {
    !citationManager.contains("nonisolated(unsafe)")
}

test("P0-3b: CitationManager is @MainActor") {
    citationManager.contains("@MainActor")
}

test("P0-3c: No MainActor.assumeIsolated hack") {
    !citationManager.contains("MainActor.assumeIsolated")
}

// ============================================================================
// MARK: - P0-4: Force Unwrap Fix Tests
// ============================================================================

print("\n=== P0-4: Force Unwrap Fixes ===")

let mainSwift = readFile("\(base)/macOS/Sources/main.swift")
let settingsWindow = readFile("\(base)/macOS/Sources/SettingsWindow.swift")

test("P0-4a: No force unwrap on statusBarItem") {
    !mainSwift.contains("private var statusBarItem: NSStatusItem!")
}

test("P0-4b: statusBarItem is optional") {
    mainSwift.contains("private var statusBarItem: NSStatusItem?")
}

test("P0-4c: menu is optional") {
    mainSwift.contains("private var menu: NSMenu?")
}

test("P0-4d: No force unwrap on charactersIgnoringModifiers") {
    !settingsWindow.contains("event.charactersIgnoringModifiers!")
}

test("P0-4e: Safe unwrap with guard let characters") {
    settingsWindow.contains("guard let characters = event.charactersIgnoringModifiers")
}

// ============================================================================
// MARK: - P0-5: Unsafe Selector Fix Tests
// ============================================================================

print("\n=== P0-5: Unsafe Selector Fixes ===")

test("P0-5a: No string-based Selector for setChartsWindowController") {
    !settingsWindow.contains("Selector((\"setChartsWindowController:\"))")
}

test("P0-5b: Uses type-safe AppDelegate cast") {
    settingsWindow.contains("NSApp.delegate as? AppDelegate")
}

test("P0-5c: No string-based undo/redo Selectors") {
    !settingsWindow.contains("Selector((\"undo:\"))")
}

test("P0-5d: Uses undoManager for undo") {
    settingsWindow.contains("self.undoManager")
}

// ============================================================================
// MARK: - P1-1: Cache TTL Fix Tests
// ============================================================================

print("\n=== P1-1: Cache TTL ===")

let cacheService = readFile("\(base)/Shared/Services/CitationCacheService.swift")

test("P1-1a: Publication cache has TTL") {
    cacheService.contains("publicationCacheTTL")
}

test("P1-1b: No 'no expiration' comment") {
    !cacheService.contains("论文缓存不设置过期时间")
}

test("P1-1c: TTL is 24 hours") {
    cacheService.contains("24 * 60 * 60")
}

// ============================================================================
// MARK: - P1-2: Race Condition Fix Tests
// ============================================================================

print("\n=== P1-2: Race Conditions ===")

test("P1-2a: No concurrent updateQueue in refreshCitations") {
    !mainSwift.contains("let updateQueue = DispatchQueue(label: \"com.citetrack.citationupdate\", attributes: .concurrent)")
}

test("P1-2b: All state mutations on main thread") {
    // Check that updatedCount is incremented directly (no barrier/async wrapping)
    mainSwift.contains("updatedCount += 1") &&
    !mainSwift.contains("updateQueue.async(flags: .barrier)")
}

test("P1-2c: Guard against concurrent refresh") {
    mainSwift.contains("guard !isUpdating else { return }")
}

// ============================================================================
// MARK: - P1-3: Core Data Index Tests
// ============================================================================

print("\n=== P1-3: Core Data Indexes ===")

test("P1-3a: Shared model has scholarId index") {
    sharedModel.contains("byScholarIdIndex")
}

test("P1-3b: Shared model has timestamp index") {
    sharedModel.contains("byTimestampIndex")
}

test("P1-3c: Shared model has compound index") {
    sharedModel.contains("compoundScholarTimestampIndex")
}

test("P1-3d: macOS model has scholarId index") {
    macOSModel.contains("byScholarIdIndex")
}

test("P1-3e: Shared model has citedScholarId index") {
    sharedModel.contains("byCitedScholarIdIndex")
}

// ============================================================================
// MARK: - P1-4: Error Handling Fix Tests
// ============================================================================

print("\n=== P1-4: Error Handling ===")

let unifiedCache = readFile("\(base)/Shared/Services/UnifiedCacheManager.swift")

test("P1-4a: No silent try? for JSON decode in loadPersistedData") {
    !unifiedCache.contains("try? JSONDecoder().decode(PersistedCacheData.self")
}

test("P1-4b: Explicit error handling for decode") {
    unifiedCache.contains("try JSONDecoder().decode(PersistedCacheData.self")
}

test("P1-4c: Explicit error handling for encode") {
    unifiedCache.contains("try JSONEncoder().encode(persisted)")
}

test("P1-4d: Error message includes localizedDescription") {
    unifiedCache.contains("error.localizedDescription")
}

// ============================================================================
// MARK: - P1-5: Core Data Thread Safety Tests
// ============================================================================

print("\n=== P1-5: Core Data Thread Safety ===")

let coreDataManager = readFile("\(base)/Shared/Managers/CoreDataManager.swift")

test("P1-5a: Background context has merge policy") {
    coreDataManager.contains("context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy")
}

test("P1-5b: Background context auto-merges") {
    coreDataManager.contains("context.automaticallyMergesChangesFromParent = true")
}

test("P1-5c: Fetch requests have batch size") {
    coreDataManager.contains("fetchBatchSize = 100")
}

test("P1-5d: Default model has createdAt attribute") {
    coreDataManager.contains("createdAtAttribute.name = \"createdAt\"")
}

test("P1-5e: Default model has source attribute") {
    coreDataManager.contains("sourceAttribute.name = \"source\"")
}

// ============================================================================
// MARK: - P2-1: God Object Split Tests
// ============================================================================

print("\n=== P2-1: God Object Split ===")

let citeTrackApp = readFile("\(base)/iOS/CiteTrack/CiteTrackApp.swift")
let lineCount = citeTrackApp.components(separatedBy: "\n").count

test("P2-1a: CiteTrackApp.swift reduced (was 4532)", {
    lineCount < 4500
}, detail: "Current: \(lineCount) lines")

test("P2-1b: ChartViews.swift exists") {
    fileExists("\(base)/iOS/CiteTrack/Views/ChartViews.swift")
}

test("P2-1c: SelectionViews.swift exists") {
    fileExists("\(base)/iOS/CiteTrack/Views/SelectionViews.swift")
}

let chartViews = readFile("\(base)/iOS/CiteTrack/Views/ChartViews.swift")
let selectionViews = readFile("\(base)/iOS/CiteTrack/Views/SelectionViews.swift")

test("P2-1d: ChartViews has CitationRankingChart") {
    chartViews.contains("struct CitationRankingChart: View")
}

test("P2-1e: ChartViews has StatCard") {
    chartViews.contains("struct StatCard: View")
}

test("P2-1f: SelectionViews has ThemeSelectionView") {
    selectionViews.contains("struct ThemeSelectionView: View")
}

test("P2-1g: SelectionViews has LanguageSelectionView") {
    selectionViews.contains("struct LanguageSelectionView: View")
}

test("P2-1h: No duplicate definitions in CiteTrackApp.swift") {
    !citeTrackApp.contains("struct CitationRankingChart: View") &&
    !citeTrackApp.contains("struct ThemeSelectionView: View") &&
    !citeTrackApp.contains("struct LanguageSelectionView: View")
}

// ============================================================================
// MARK: - P2-3: Batch Delete Tests
// ============================================================================

print("\n=== P2-3: Batch Delete Operations ===")

let historyManager = readFile("\(base)/Shared/Managers/CitationHistoryManager.swift")

test("P2-3a: Uses NSBatchDeleteRequest for scholar history delete") {
    historyManager.contains("NSBatchDeleteRequest(fetchRequest: fetchRequest)")
}

test("P2-3b: No individual entity deletion loop for deleteHistory") {
    // Check that the old pattern is gone
    let deleteHistorySection = historyManager.components(separatedBy: "func deleteHistory(for scholarId:").last ?? ""
    let sectionEnd = deleteHistorySection.components(separatedBy: "func cleanupOldEntries").first ?? deleteHistorySection
    return !sectionEnd.contains("for entity in entities")
}

test("P2-3c: Uses batch delete for cleanup") {
    let cleanupSection = historyManager.components(separatedBy: "func cleanupOldEntries").last ?? ""
    return cleanupSection.contains("NSBatchDeleteRequest")
}

test("P2-3d: Refreshes view context after batch delete") {
    historyManager.contains("refreshAllObjects()")
}

// ============================================================================
// MARK: - P2-2: macOS main.swift Improvements
// ============================================================================

print("\n=== P2-2: macOS main.swift Improvements ===")

test("P2-2a: chartsWindowController is accessible (not private)") {
    mainSwift.contains("var chartsWindowController: NSWindowController?") &&
    !mainSwift.contains("private var chartsWindowController")
}

test("P2-2b: Has serial citation update queue") {
    mainSwift.contains("citationUpdateQueue = DispatchQueue(label:")
}

test("P2-2c: rebuildMenu uses guard let menu") {
    mainSwift.contains("guard let menu = menu else { return }")
}

test("P2-2d: Uses optional chaining for statusBarItem") {
    mainSwift.contains("statusBarItem?.isVisible")
}

// ============================================================================
// MARK: - Report
// ============================================================================

print("\n")
print("=" .padding(toLength: 70, withPad: "=", startingAt: 0))
print("  CITETRACK TEST REPORT")
print("=" .padding(toLength: 70, withPad: "=", startingAt: 0))
print("")

let categories = [
    ("P0-1 Core Data Model Sync", "P0-1"),
    ("P0-2 Thread.sleep Removal", "P0-2"),
    ("P0-3 Singleton Thread Safety", "P0-3"),
    ("P0-4 Force Unwrap Fixes", "P0-4"),
    ("P0-5 Unsafe Selector Fixes", "P0-5"),
    ("P1-1 Cache TTL", "P1-1"),
    ("P1-2 Race Conditions", "P1-2"),
    ("P1-3 Core Data Indexes", "P1-3"),
    ("P1-4 Error Handling", "P1-4"),
    ("P1-5 Core Data Thread Safety", "P1-5"),
    ("P2-1 God Object Split", "P2-1"),
    ("P2-2 macOS Improvements", "P2-2"),
    ("P2-3 Batch Delete", "P2-3"),
]

for (catName, prefix) in categories {
    let catTests = testResults.filter { $0.name.hasPrefix(prefix) }
    let catPassed = catTests.filter { $0.passed }.count
    let catTotal = catTests.count
    let status = catPassed == catTotal ? "PASS" : "FAIL"
    let icon = catPassed == catTotal ? "✅" : "❌"
    print("\(icon) \(catName): \(catPassed)/\(catTotal) \(status)")

    for t in catTests where !t.passed {
        print("   ❌ \(t.name): \(t.detail)")
    }
}

print("")
print("-" .padding(toLength: 70, withPad: "-", startingAt: 0))
print("Total: \(passedTests)/\(totalTests) tests passed (\(failedTests) failed)")
let rate = totalTests > 0 ? Double(passedTests) / Double(totalTests) * 100.0 : 0.0
print("Pass Rate: \(String(format: "%.1f", rate))%")
print("")

if failedTests == 0 {
    print("🎉 ALL TESTS PASSED")
} else {
    print("⚠️  \(failedTests) test(s) failed — see details above")
}
print("=" .padding(toLength: 70, withPad: "=", startingAt: 0))

// Exit with appropriate code
exit(failedTests > 0 ? 1 : 0)
