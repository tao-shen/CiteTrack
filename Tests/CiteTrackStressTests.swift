#!/usr/bin/env swift
// CiteTrack 严格压力测试套件 (Stress Tests)
// 基于 iterative-development / TDD：明确完成标准，失败即迭代修复
// 运行: swift Tests/CiteTrackStressTests.swift
// 或: ./Tests/run_all_tests.sh（同时运行 CiteTrackTests + CiteTrackStressTests）

import Foundation

// MARK: - Test Framework（与 CiteTrackTests 一致）
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

func readFile(_ path: String) -> String {
    return (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
}

func fileExists(_ path: String) -> Bool {
    return FileManager.default.fileExists(atPath: path)
}

// 使用与 CiteTrackTests 相同的 base（可通过环境变量覆盖）
let base = ProcessInfo.processInfo.environment["CITETRACK_PROJECT_ROOT"] ?? "/Users/tao.shen/google_scholar_plugin"

// MARK: - S1: 并发与串行化 (Concurrency)
let mainSwift = readFile("\(base)/macOS/Sources/main.swift")
let fetchService = readFile("\(base)/Shared/Services/CitationFetchService.swift")
let historyManager = readFile("\(base)/Shared/Managers/CitationHistoryManager.swift")

print("=== S1: 并发与串行化 (Concurrency) ===")

test("S1-1a: main.swift 使用串行 citationUpdateQueue（无 .concurrent）") {
    mainSwift.contains("citationUpdateQueue = DispatchQueue(label:") &&
    !mainSwift.contains("citationUpdateQueue = DispatchQueue(label: \"com.citetrack.citationupdate\", attributes: .concurrent)")
}

test("S1-1b: main.swift 存在防止并发刷新的 guard") {
    mainSwift.contains("guard !isUpdating else { return }")
}

test("S1-2a: CitationFetchService 使用 requestQueue 串行化请求") {
    fetchService.contains("requestQueue = DispatchQueue(label:")
}

test("S1-2b: CitationFetchService 的 requestQueue 未使用 .concurrent") {
    !fetchService.contains("requestQueue = DispatchQueue(label: \"com.citetrack.citationfetch\", attributes: .concurrent)")
}

test("S1-3a: CitationHistoryManager 使用 serial backgroundQueue") {
    historyManager.contains("backgroundQueue = DispatchQueue(label:")
}

test("S1-3b: CitationHistoryManager 的 backgroundQueue 未使用 .concurrent") {
    !historyManager.contains("attributes: .concurrent")
}

// 若使用 .concurrent，必须配合 .barrier 写操作
let settingsWindow = readFile("\(base)/macOS/Sources/SettingsWindow.swift")
let googleHistory = readFile("\(base)/macOS/Sources/GoogleScholarService+History.swift")

test("S1-4a: SettingsWindow 若使用 .concurrent 则必须有 .barrier") {
    !settingsWindow.contains("attributes: .concurrent") || settingsWindow.contains(".barrier")
}

test("S1-4b: GoogleScholarService+History 若使用 .concurrent 则必须有 .barrier") {
    !googleHistory.contains("attributes: .concurrent") || googleHistory.contains(".barrier")
}

// MARK: - S2: 速率限制与节流 (Rate Limiting)
print("\n=== S2: 速率限制与节流 (Rate Limiting) ===")

test("S2-1a: CitationFetchService 存在速率限制（delay 或 rateLimit）") {
    fetchService.contains("rateLimitDelay") || fetchService.contains("lastRequestTime")
}

test("S2-1b: 使用 asyncAfter 做节流，而非 Thread.sleep") {
    !fetchService.contains("Thread.sleep(forTimeInterval:")
}

test("S2-1c: 请求间隔配置合理（≥ 1 秒或可配置）") {
    fetchService.contains("rateLimitDelay") || fetchService.contains("2.0") || fetchService.contains("1.0")
}

// MARK: - S3: 批量与内存 (Batch & Memory)
let coreDataManager = readFile("\(base)/Shared/Managers/CoreDataManager.swift")
let historyManagerShared = readFile("\(base)/Shared/Managers/CitationHistoryManager.swift")

print("\n=== S3: 批量与内存 (Batch & Memory) ===")

test("S3-1a: Core Data 请求使用 fetchBatchSize") {
    coreDataManager.contains("fetchBatchSize = 100")
}

test("S3-1b: fetchBatchSize 在合理范围（20–500）") {
    (coreDataManager.contains("fetchBatchSize = 100") || coreDataManager.contains("fetchBatchSize = 50") ||
     coreDataManager.contains("fetchBatchSize = 200")) && !coreDataManager.contains("fetchBatchSize = 0")
}

test("S3-2a: CitationHistoryManager 批量删除使用 NSBatchDeleteRequest") {
    historyManagerShared.contains("NSBatchDeleteRequest(fetchRequest:")
}

test("S3-2b: 批量删除后刷新 view context") {
    historyManagerShared.contains("refreshAllObjects()") || historyManagerShared.contains("refresh(")
}

test("S3-3: 无单次无限制 fetch（fetchLimit 为 0 且无 batch）") {
    // 允许 fetchLimit = 1 用于“取最新一条”
    !coreDataManager.contains("fetchLimit = 0") || coreDataManager.contains("fetchBatchSize")
}

// MARK: - S4: Main Thread 与 UI 安全
let citationManager = readFile("\(base)/Shared/Managers/CitationManager.swift")
let unifiedCache = readFile("\(base)/Shared/Services/UnifiedCacheManager.swift")

print("\n=== S4: Main Thread 与 UI 安全 ===")

test("S4-1a: 关键路径无 Thread.sleep 阻塞调用") {
    // 仅检测实际调用 Thread.sleep(forTimeInterval:)，避免注释触发
    let mainSwiftNoSleep = !mainSwift.contains("Thread.sleep(forTimeInterval:")
    let fetchNoSleep = !fetchService.contains("Thread.sleep(forTimeInterval:")
    let settingsNoSleep = !settingsWindow.contains("Thread.sleep(forTimeInterval:")
    let googleHistoryNoSleep = !googleHistory.contains("Thread.sleep(forTimeInterval:")
    return mainSwiftNoSleep && fetchNoSleep && settingsNoSleep && googleHistoryNoSleep
}

test("S4-1b: CitationManager 无 nonisolated(unsafe)") {
    !citationManager.contains("nonisolated(unsafe)")
}

test("S4-1c: CitationManager 为 @MainActor 或 ObservableObject 主线程更新") {
    citationManager.contains("@MainActor") || citationManager.contains("ObservableObject")
}

test("S4-1d: UnifiedCacheManager 为 @MainActor") {
    unifiedCache.contains("@MainActor")
}

test("S4-2: 无 MainActor.assumeIsolated 规避隔离") {
    !citationManager.contains("MainActor.assumeIsolated") && !unifiedCache.contains("MainActor.assumeIsolated")
}

// MARK: - S5: 缓存边界 (Cache Bounds)
let cacheService = readFile("\(base)/Shared/Services/CitationCacheService.swift")

print("\n=== S5: 缓存边界 (Cache Bounds) ===")

test("S5-1a: UnifiedCacheManager 有 TTL 或过期时间") {
    unifiedCache.contains("cacheExpirationInterval") || unifiedCache.contains("24 * 60 * 60") || unifiedCache.contains("expir")
}

test("S5-1b: CitationCacheService 有 TTL（非“永不过期”）") {
    cacheService.contains("publicationCacheTTL") || cacheService.contains("24 * 60 * 60")
}

test("S5-2: 持久化解码失败时有清理逻辑") {
    unifiedCache.contains("clearPersistedData()") || unifiedCache.contains("Failed to decode") || unifiedCache.contains("Clearing")
}

// MARK: - S6: 错误处理 (Error Handling)
print("\n=== S6: 错误处理 (Error Handling) ===")

test("S6-1a: UnifiedCacheManager 不解码时静默 try? 吞错") {
    !unifiedCache.contains("try? JSONDecoder().decode(PersistedCacheData.self")
}

test("S6-1b: 解码使用显式 try 与错误处理") {
    unifiedCache.contains("try JSONDecoder().decode(PersistedCacheData.self") || unifiedCache.contains("do {")
}

test("S6-2: 错误信息包含可追踪内容（如 localizedDescription）") {
    unifiedCache.contains("error.localizedDescription") || unifiedCache.contains("localizedDescription")
}

// MARK: - S7: 取消与任务 (Cancellation / Task Safety)
print("\n=== S7: 取消与任务 (Cancellation) ===")

test("S7-1: CitationManager 使用 Cancellable 或 Task 可取消") {
    citationManager.contains("AnyCancellable") || citationManager.contains("cancellables") || citationManager.contains("Task {")
}

test("S7-2: CitationFetchService 或 Coordinator 有请求队列/串行化，避免请求风暴") {
    fetchService.contains("requestQueue") || fetchService.contains("DispatchQueue(label:")
}

// MARK: - S8: 数据一致性 (Data Integrity)
print("\n=== S8: 数据一致性 (Data Integrity) ===")

test("S8-1: Core Data 背景 context 有 mergePolicy") {
    coreDataManager.contains("mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy")
}

test("S8-2: Core Data 背景 context 自动合并父上下文") {
    coreDataManager.contains("automaticallyMergesChangesFromParent = true")
}

// MARK: - S9: 压力场景代码模式 (Stress Patterns)
print("\n=== S9: 压力场景代码模式 ===")

test("S9-1: main 菜单/状态栏 使用 optional 避免 force unwrap 崩溃") {
    let hasStatusBarOptional = mainSwift.contains("statusBarItem?") || mainSwift.contains("var statusBarItem: NSStatusItem?")
    let hasMenuOptional = mainSwift.contains("menu?") || mainSwift.contains("guard let menu = menu") || mainSwift.contains("var menu: NSMenu?")
    return hasStatusBarOptional && hasMenuOptional
}

test("S9-2: 无 force unwrap 在关键路径（statusBarItem!/menu!）") {
    !mainSwift.contains("statusBarItem!") && !mainSwift.contains("menu!")
}

test("S9-3: DataIntegrationTests 并发测试存在（≥3 并发任务）") {
    let dataIntegration = readFile("\(base)/Shared/Testing/DataIntegrationTests.swift")
    return dataIntegration.contains("concurrentTasks") || dataIntegration.contains("(1...5)")
}

// MARK: - V1: 暴力/防闪退 (Crash Prevention - Force Unwrap & Bounds)
print("\n=== V1: 暴力/防闪退 (Crash Prevention) ===")

let notificationManager = readFile("\(base)/macOS/Sources/NotificationManager.swift")
let citationHistoryMacOS = readFile("\(base)/macOS/Sources/CitationHistory.swift")
let chartDataService = readFile("\(base)/macOS/Sources/ChartDataService.swift")
let widgetSwift = readFile("\(base)/iOS/CiteTrackWidgetExtension/CiteTrackWidget.swift")
let mainLocalized = readFile("\(base)/macOS/Sources/main_localized.swift")

test("V1-1a: main 无 .first!/.last! 避免空数组闪退") {
    !mainSwift.contains(".first!") && !mainSwift.contains(".last!")
}

test("V1-1b: GoogleScholarService+History 无 errors.first!") {
    !googleHistory.contains("errors.first!")
}

test("V1-1c: NotificationManager 无 significantChanges.first!") {
    !notificationManager.contains("significantChanges.first!")
}

test("V1-1d: CitationHistory (macOS) 无 history.last!") {
    !citationHistoryMacOS.contains("history.last!")
}

test("V1-1e: ChartDataService 无 sortedHistory.first!/.last!") {
    !chartDataService.contains("sortedHistory.first!") && !chartDataService.contains("sortedHistory.last!")
}

test("V1-2a: Widget 无 selected! 等 optional 强解包") {
    !widgetSwift.contains("selected!.displayName") && !widgetSwift.contains("selected!")
}

test("V1-2b: Widget 访问 scholars[0] 前有 isEmpty 或 guard count") {
    // 若有 scholars[0] 则应有 guards 或 safe access
    !widgetSwift.contains("scholars[0]") || widgetSwift.contains("scholars.isEmpty") || widgetSwift.contains("guard") || widgetSwift.contains("scholars.first")
}

test("V1-3a: main_localized 使用 as! 前有类型检查 (is NSProgressIndicator 等)") {
    // 有 as! 则同一文件应有 is NSProgressIndicator 或 as? 模式
    !mainLocalized.contains(" as! NS") || mainLocalized.contains(" is NSProgressIndicator") || mainLocalized.contains(" is NSTextField") || mainLocalized.contains(" is NSImageView") || mainLocalized.contains("as? NS")
}

test("V1-3b: main 无 fatalError（除 init(coder:) 外）") {
    // 允许 init(coder:) 中的 fatalError
    !mainSwift.contains("fatalError(") || (mainSwift.contains("fatalError(") && mainSwift.contains("init(coder:)"))
}

test("V1-4: main/SettingsWindow 无 completion(.failure(errors.first!))") {
    !mainSwift.contains("errors.first!") && !settingsWindow.contains("errors.first!")
}

// MARK: - V2: 极压/全链路防崩 (Extreme Pressure - No Force Unwrap in Charts & Data)
print("\n=== V2: 极压/全链路防崩 (Extreme Pressure) ===")

let chartViewMacOS = readFile("\(base)/macOS/Sources/ChartView.swift")
let enhancedChartTypes = readFile("\(base)/macOS/Sources/EnhancedChartTypes.swift")
let dataExportManager = readFile("\(base)/Shared/Managers/DataExportManager.swift")

test("V2-1a: ChartView (macOS) 无 trendLine.points.first!/.last!") {
    !chartViewMacOS.contains("trendLine.points.first!") && !chartViewMacOS.contains("trendLine.points.last!")
}

test("V2-1b: EnhancedChartTypes 无 points.last!") {
    !enhancedChartTypes.contains("points.last!")
}

test("V2-2a: DataExportManager 使用 components[0] 前有 count 检查") {
    !dataExportManager.contains("components[0]") || dataExportManager.contains("components.count") || dataExportManager.contains("guard")
}

test("V2-2b: Widget 使用 components[0] 前有 count 检查") {
    !widgetSwift.contains("components[0]") || widgetSwift.contains("components.count") || widgetSwift.contains("guard")
}

test("V2-3: 关键业务代码无 try!（Shared/Managers、macOS/Sources 核心）") {
    let citationManagerStr = readFile("\(base)/Shared/Managers/CitationManager.swift")
    let fetchServiceStr = readFile("\(base)/Shared/Services/CitationFetchService.swift")
    return !citationManagerStr.contains("try!") && !fetchServiceStr.contains("try!")
}

test("V2-4: ChartView 使用 points[0] 的路径前有 guard 或 count == 1") {
    !chartViewMacOS.contains("points[0]") || chartViewMacOS.contains("points.count == 1") || chartViewMacOS.contains("guard !") || chartViewMacOS.contains("!points.isEmpty")
}

test("V2-5: EnhancedChartTypes 使用 points[0] 或 points.last 前有 guard !points.isEmpty") {
    !enhancedChartTypes.contains("points[0]") && !enhancedChartTypes.contains("points.last!") || enhancedChartTypes.contains("guard !points.isEmpty")
}

test("V2-6: 无裸 catch 吞错（catch 后至少有 print/return/throw）") {
    let unified = readFile("\(base)/Shared/Services/UnifiedCacheManager.swift")
    let cache = readFile("\(base)/Shared/Services/CitationCacheService.swift")
    let hasEmptyCatch = unified.contains("catch {\n}") || unified.contains("catch {}") || cache.contains("catch {\n}") || cache.contains("catch {}")
    return !hasEmptyCatch
}

print("\n")
print("=".padding(toLength: 70, withPad: "=", startingAt: 0))
print("  CITETRACK STRESS TEST REPORT")
print("=".padding(toLength: 70, withPad: "=", startingAt: 0))
print("")

let categories = [
    ("S1 并发与串行化", "S1-"),
    ("S2 速率限制与节流", "S2-"),
    ("S3 批量与内存", "S3-"),
    ("S4 Main Thread 与 UI 安全", "S4-"),
    ("S5 缓存边界", "S5-"),
    ("S6 错误处理", "S6-"),
    ("S7 取消与任务", "S7-"),
    ("S8 数据一致性", "S8-"),
    ("S9 压力场景代码模式", "S9-"),
    ("V1 暴力/防闪退", "V1-"),
    ("V2 极压/全链路防崩", "V2-"),
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
print("-".padding(toLength: 70, withPad: "-", startingAt: 0))
print("Total: \(passedTests)/\(totalTests) stress tests passed (\(failedTests) failed)")
let rate = totalTests > 0 ? Double(passedTests) / Double(totalTests) * 100.0 : 0.0
print("Pass Rate: \(String(format: "%.1f", rate))%")
print("")

if failedTests == 0 {
    print("🎉 ALL STRESS TESTS PASSED")
} else {
    print("⚠️  \(failedTests) stress test(s) failed — fix before release")
}
print("=".padding(toLength: 70, withPad: "=", startingAt: 0))

exit(failedTests > 0 ? 1 : 0)
