import Foundation
import WidgetKit
import SwiftUI
import UIKit

// MARK: - 数字格式化扩展
// Widget number formatting moved to Shared/Models/WidgetModels.swift

// MARK: - 统一数据模型

/// 引用历史记录
public struct CitationHistory: Codable, Identifiable, Equatable {
    public let id: UUID
    public let scholarId: String
    public let citationCount: Int
    public let timestamp: Date
    
    public init(scholarId: String, citationCount: Int, timestamp: Date = Date()) {
        self.id = UUID()
        self.scholarId = scholarId
        self.citationCount = citationCount
        self.timestamp = timestamp
    }
    
    public init(id: UUID, scholarId: String, citationCount: Int, timestamp: Date) {
        self.id = id
        self.scholarId = scholarId
        self.citationCount = citationCount
        self.timestamp = timestamp
    }
}

// Widget models moved to Shared/Models/WidgetModels.swift

/// 统一的数据管理器
public class DataManager: ObservableObject {
    public static let shared = DataManager()
    // 使用全局定义的 appGroupIdentifier
    
    private let userDefaults: UserDefaults = {
        // 优先尝试使用 App Group，失败则回退到标准 UserDefaults
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            print("✅ [DataManager] 使用 App Group UserDefaults")
            return appGroupDefaults
        } else {
            print("⚠️ [DataManager] App Group 不可用，使用标准 UserDefaults")
            return .standard
        }
    }()
    private let scholarsKey = "ScholarsList"
    private let historyKey = "CitationHistoryData"
    private let pinnedKey = "PinnedScholarIDs"
    private let orderKey = "ScholarDisplayOrder"
    
    // 发布的数据
    @Published public var scholars: [Scholar] = []
    @Published public var lastRefreshTime: Date? = nil
    @Published public var pinnedIds: Set<String> = []
    @Published public var displayOrder: [String] = []
    
    private init() {
        print("🔍 [DataManager] 初始化，App Group ID: \(appGroupIdentifier)")
        testAppGroupAccess()
        performAppGroupMigrationIfNeeded()
        loadScholars()
        // 加载置顶集合
        if let arr = userDefaults.array(forKey: pinnedKey) as? [String] {
            pinnedIds = Set(arr)
            print("🧪 [DataManager] 加载置顶学者: \(pinnedIds.count) 个")
        }
        // 加载显示顺序
        if let arr = userDefaults.array(forKey: orderKey) as? [String] {
            displayOrder = arr
            print("🧪 [DataManager] 加载排序序列: \(displayOrder.count) 项")
        }
        // 若未初始化顺序，以当前学者顺序构建
        if displayOrder.isEmpty { displayOrder = scholars.map { $0.id }; saveOrder() }
        // 初始化全局上次刷新时间（优先App Group）
        if let ag = UserDefaults(suiteName: appGroupIdentifier),
           let t = ag.object(forKey: "LastRefreshTime") as? Date {
            lastRefreshTime = t
            print("🧪 [DataManager] 初始化读取 LastRefreshTime(AppGroup)=\(t)")
        } else if let t = UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date {
            lastRefreshTime = t
            print("🧪 [DataManager] 初始化读取 LastRefreshTime(Standard)=\(t)")
        }
        
        // 初始化时主动同步小组件数据
        saveWidgetData()
        print("🔄 [DataManager] 初始化完成，已触发小组件数据同步")

        // 启动监听与轮询，确保主App能感知小组件写入
        setupLastRefreshObservers()
    }
    
    /// 测试 App Group 访问权限
    private func testAppGroupAccess() {
        print("🔍 [DataManager] 测试 App Group 访问权限...")
        
        if let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            // 测试写入和读取 - 使用同步方式避免CFPreferences警告
            let testKey = "TestAppGroupAccess"
            let testValue = "测试数据_\(Date().timeIntervalSince1970)"
            groupDefaults.set(testValue, forKey: testKey)
            groupDefaults.synchronize() // 强制同步，避免异步访问问题
            
            if groupDefaults.string(forKey: testKey) != nil {
                print("✅ [DataManager] App Group 读写测试成功")
            } else {
                print("❌ [DataManager] App Group 读取测试失败")
            }
            
            // 清理测试数据
            groupDefaults.removeObject(forKey: testKey)
            groupDefaults.synchronize()
        } else {
            print("❌ [DataManager] 无法创建 App Group UserDefaults，请检查entitlements配置")
        }
    }
    
    // MARK: - 学者管理
    
    /// 加载所有学者
    public func loadScholars() {
        if let data = userDefaults.data(forKey: scholarsKey),
           let decodedScholars = try? JSONDecoder().decode([Scholar].self, from: data) {
            scholars = decodedScholars
        } else {
            scholars = []
        }
    }
    
    /// 保存所有学者
    private func saveScholars() {
        if let encoded = try? JSONEncoder().encode(scholars) {
            userDefaults.set(encoded, forKey: scholarsKey)
            // 同时为小组件保存数据到标准位置
            saveWidgetData()
        }
        // 确保顺序中包含所有现有学者
        let currentIds = Set(scholars.map { $0.id })
        var newOrder: [String] = []
        for id in displayOrder where currentIds.contains(id) { newOrder.append(id) }
        for id in scholars.map({ $0.id }) where !newOrder.contains(id) { newOrder.append(id) }
        if newOrder != displayOrder { displayOrder = newOrder; saveOrder() }
    }

    /// 保存置顶集合
    private func savePinned() {
        userDefaults.set(Array(pinnedIds), forKey: pinnedKey)
    }

    /// 保存自定义显示顺序
    private func saveOrder() {
        userDefaults.set(displayOrder, forKey: orderKey)
    }

    /// 列表展示顺序：置顶优先，其余保持原有顺序
    public var scholarsForList: [Scholar] {
        let indexInOrder: [String: Int] = Dictionary(uniqueKeysWithValues: displayOrder.enumerated().map { ($0.element, $0.offset) })
        return scholars.sorted { a, b in
            let aPinned = pinnedIds.contains(a.id)
            let bPinned = pinnedIds.contains(b.id)
            if aPinned != bPinned { return aPinned && !bPinned }
            let ia = indexInOrder[a.id] ?? Int.max
            let ib = indexInOrder[b.id] ?? Int.max
            return ia < ib
        }
    }

    public func isPinned(_ id: String) -> Bool { pinnedIds.contains(id) }
    public func pinScholar(id: String) {
        pinnedIds.insert(id)
        // 置顶时将其移动到显示顺序最前
        displayOrder.removeAll { $0 == id }
        displayOrder.insert(id, at: 0)
        savePinned(); saveOrder()
        print("📌 [DataManager] 已置顶学者并移动到顶部: \(id)")
    }
    public func unpinScholar(id: String) {
        if pinnedIds.remove(id) != nil {
            savePinned(); saveOrder()
            print("📌 [DataManager] 已取消置顶学者: \(id)")
        }
    }
    public func togglePin(id: String) { isPinned(id) ? unpinScholar(id: id) : pinScholar(id: id) }
    
    /// 专门为小组件保存数据
    private func saveWidgetData() {
        // 转换为小组件格式，包含增长数据
        let widgetScholars = scholars.map { scholar in
            let multiPeriodGrowth = getMultiPeriodGrowth(for: scholar.id)
            return WidgetScholarInfo(
                id: scholar.id,
                displayName: scholar.displayName,
                institution: nil, // Scholar 模型暂无 institution 字段
                citations: scholar.citations,
                hIndex: nil, // Scholar 模型暂无 hIndex 字段
                lastUpdated: scholar.lastUpdated,
                weeklyGrowth: multiPeriodGrowth?.weeklyGrowth?.growth,
                monthlyGrowth: multiPeriodGrowth?.monthlyGrowth?.growth,
                quarterlyGrowth: multiPeriodGrowth?.quarterlyGrowth?.growth
            )
        }
        
        if let encoded = try? JSONEncoder().encode(widgetScholars) {
            // 保存到当前使用的UserDefaults（可能是App Group或标准存储）
            userDefaults.set(encoded, forKey: "WidgetScholars")
            
            // 为了向后兼容，同时保存到标准存储
            UserDefaults.standard.set(encoded, forKey: "WidgetScholars")
            
            print("✅ [DataManager] 已为小组件保存 \(widgetScholars.count) 位学者数据（App Group + 标准存储）")
        }
    }

    // MARK: - LastRefreshTime 同步（监听Darwin通知 + 轮询兜底）
    private func setupLastRefreshObservers() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, Unmanaged.passUnretained(self).toOpaque(), { (_, observer, name, _, _) in
            guard let name = name else { return }
            let n = name.rawValue as String
            if n == "com.citetrack.lastRefreshTimeUpdated" {
                DispatchQueue.main.async {
                    let manager = Unmanaged<DataManager>.fromOpaque(observer!).takeUnretainedValue()
                    let ag = UserDefaults(suiteName: appGroupIdentifier)
                    let t = (ag?.object(forKey: "LastRefreshTime") as? Date) ?? (UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date)
                    let old = manager.lastRefreshTime
                    manager.lastRefreshTime = t
                    print("🧪 [DataManager] 收到Darwin通知，更新 lastRefreshTime: old=\(old?.description ?? "nil") -> new=\(t?.description ?? "nil")")
                    // 合并来自Widget的最新每学者数据，保持App与Widget一致
                    manager.mergeLatestScholarsFromWidget()
                }
            }
        }, "com.citetrack.lastRefreshTimeUpdated" as CFString, nil, .deliverImmediately)

        // 轮询兜底
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let ag = UserDefaults(suiteName: appGroupIdentifier)
            let t = (ag?.object(forKey: "LastRefreshTime") as? Date) ?? (UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date)
            if self.lastRefreshTime == nil || self.lastRefreshTime != t {
                let old = self.lastRefreshTime
                self.lastRefreshTime = t
                print("🧪 [DataManager] 轮询捕获 LastRefreshTime 变更: old=\(old?.description ?? "nil") -> new=\(t?.description ?? "nil")")
                self.mergeLatestScholarsFromWidget()
            }
        }

        // 应用进入前台时，立即同步一次
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            let ag = UserDefaults(suiteName: appGroupIdentifier)
            let t = (ag?.object(forKey: "LastRefreshTime") as? Date) ?? (UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date)
            if self.lastRefreshTime != t {
                let old = self.lastRefreshTime
                self.lastRefreshTime = t
                print("🧪 [DataManager] 前台激活同步 LastRefreshTime: old=\(old?.description ?? "nil") -> new=\(t?.description ?? "nil")")
                self.mergeLatestScholarsFromWidget()
            } else {
                print("🧪 [DataManager] 前台激活检查 LastRefreshTime 无变化: \(t?.description ?? "nil")")
                // 即使时间没变化，也尝试一次合并，防止上次错过
                self.mergeLatestScholarsFromWidget()
            }
        }
    }

    /// 从 App Group 的 WidgetScholars 合并最新每学者数据到主应用数据源
    private func mergeLatestScholarsFromWidget() {
        guard let data = (UserDefaults(suiteName: appGroupIdentifier)?.data(forKey: "WidgetScholars") ?? UserDefaults.standard.data(forKey: "WidgetScholars")) else {
            return
        }
        guard let widgetScholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) else { return }
        var changed = false
        var updated = scholars
        for (idx, s) in scholars.enumerated() {
            if let w = widgetScholars.first(where: { $0.id == s.id }) {
                var newS = s
                // 同步引用数
                if newS.citations != w.citations {
                    newS.citations = w.citations
                    changed = true
                }
                // 同步每学者更新时间（优先按学者的 LastRefreshTime_<id>，否则用全局，最后回退 w.lastUpdated）
                let lastKey = "LastRefreshTime_\(s.id)"
                let perScholarTime = (UserDefaults(suiteName: appGroupIdentifier)?.object(forKey: lastKey) as? Date) ?? (UserDefaults.standard.object(forKey: lastKey) as? Date)
                let candidateTime = perScholarTime ?? self.lastRefreshTime ?? w.lastUpdated
                if newS.lastUpdated != candidateTime {
                    newS.lastUpdated = candidateTime
                    changed = true
                }
                updated[idx] = newS
            }
        }
        if changed {
            scholars = updated
            saveScholars()
            print("🧪 [DataManager] 已合并 WidgetScholars 到主应用数据：学者数=\(updated.count)")
        } else {
            print("🧪 [DataManager] 合并检查：无需要更新的学者数据")
        }
    }
    
    /// 🔄 乔布斯式简洁：一键刷新所有小组件
    public func refreshWidgets() {
        // 先更新小组件数据（包含最新的增长统计）
        saveWidgetData()
        
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 [DataManager] 已触发小组件刷新")
        #endif
    }

    // MARK: - Migration
    /// 将旧版（标准 UserDefaults）中的数据迁移到 App Group，避免升级后数据“丢失”
    private func performAppGroupMigrationIfNeeded() {
        guard let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        let migrationFlagKey = "DidMigrateToAppGroup"
        if groupDefaults.bool(forKey: migrationFlagKey) { return }

        // 若 App Group 已有数据，直接标记为已迁移
        let groupHasScholars = (groupDefaults.data(forKey: scholarsKey) ?? Data()).isEmpty == false
        let groupHasHistory = (groupDefaults.data(forKey: historyKey) ?? Data()).isEmpty == false
        if groupHasScholars || groupHasHistory {
            groupDefaults.set(true, forKey: migrationFlagKey)
            return
        }

        // 从旧的标准 UserDefaults 读取
        let standard = UserDefaults.standard
        let legacyScholars = standard.data(forKey: scholarsKey)
        let legacyHistory = standard.data(forKey: historyKey)

        var migrated = false
        if let data = legacyScholars, !data.isEmpty {
            groupDefaults.set(data, forKey: scholarsKey)
            migrated = true
        }
        if let data = legacyHistory, !data.isEmpty {
            groupDefaults.set(data, forKey: historyKey)
            migrated = true
        }

        if migrated {
            groupDefaults.set(true, forKey: migrationFlagKey)
            #if os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            print("✅ [DataManager] 已从标准存储迁移数据到 App Group")
        }
    }
    
    /// 添加学者（自动去重）
    public func addScholar(_ scholar: Scholar) {
        if !scholars.contains(where: { $0.id == scholar.id }) {
            scholars.append(scholar)
            saveScholars()
            #if os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            print("✅ [DataManager] 添加学者: \(scholar.displayName)")
        } else {
            print("⚠️ [DataManager] 学者已存在: \(scholar.displayName)")
        }
    }
    
    /// 更新学者信息
    public func updateScholar(_ scholar: Scholar) {
        if let index = scholars.firstIndex(where: { $0.id == scholar.id }) {
            scholars[index] = scholar
            saveScholars()
            // 标记该学者刷新完成：写入 LastRefreshTime_<id> 并清除进行中标记
            markRefreshDone(for: scholar.id)
            #if os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            print("✅ [DataManager] 更新学者: \(scholar.displayName)")
        } else {
            // 如果不存在则添加
            addScholar(scholar)
        }
    }
    
    /// 标记某个学者的刷新完成（写入 LastRefreshTime_<id>，清除 RefreshInProgress_<id>/RefreshStartTime_<id>）
    private func markRefreshDone(for scholarId: String, at date: Date = Date()) {
        let groupID = appGroupIdentifier
        let lastKey = "LastRefreshTime_\(scholarId)"
        let inKey = "RefreshInProgress_\(scholarId)"
        let startKey = "RefreshStartTime_\(scholarId)"
        
        if let appGroup = UserDefaults(suiteName: groupID) {
            appGroup.set(date, forKey: lastKey)
            appGroup.set(date, forKey: "LastRefreshTime") // 兼容全局回退
            appGroup.set(false, forKey: inKey)
            appGroup.removeObject(forKey: startKey)
            appGroup.synchronize()
        }
        UserDefaults.standard.set(date, forKey: lastKey)
        UserDefaults.standard.set(date, forKey: "LastRefreshTime")
        UserDefaults.standard.set(false, forKey: inKey)
        UserDefaults.standard.removeObject(forKey: startKey)
        print("✅ [DataManager] 标记刷新完成: sid=\(scholarId) at=\(date)")
    }
    
    /// 删除学者
    public func removeScholar(id: String) {
        scholars.removeAll { $0.id == id }
        // 移除置顶状态
        if pinnedIds.contains(id) { pinnedIds.remove(id); savePinned() }
        // 移除排序中的该项
        displayOrder.removeAll { $0 == id }
        saveOrder()
        saveScholars()
        
        // 同时删除相关历史记录
        removeAllHistory(for: id)
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        print("✅ [DataManager] 删除学者: \(id)")
    }

    // MARK: - 排序拖拽
    public func applyMove(from source: IndexSet, to destination: Int) {
        var ids = scholarsForList.map { $0.id }
        ids.move(fromOffsets: source, toOffset: destination)
        // 用新的显示顺序覆盖 displayOrder 的相对顺序
        displayOrder = ids
        saveOrder()
        print("🧪 [DataManager] 已应用拖拽排序: count=\(ids.count)")
    }
    
    /// 删除所有学者
    public func removeAllScholars() {
        scholars.removeAll()
        saveScholars()
        
        // 同时清理所有历史记录
        clearAllHistory()
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        print("✅ [DataManager] 删除所有学者")
    }
    
    /// 获取学者信息
    public func getScholar(id: String) -> Scholar? {
        return scholars.first { $0.id == id }
    }
    
    // MARK: - 历史记录管理
    
    /// 获取所有历史记录
    private func getAllHistory() -> [CitationHistory] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([CitationHistory].self, from: data) else {
            return []
        }
        return history
    }
    
    /// 保存所有历史记录
    private func saveAllHistory(_ history: [CitationHistory]) {
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
    
    /// 添加历史记录
    public func addHistory(_ history: CitationHistory) {
        var allHistory = getAllHistory()
        allHistory.append(history)
        saveAllHistory(allHistory)
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        print("✅ [DataManager] 保存历史记录: \(history.scholarId) - \(history.citationCount)")
    }
    
    /// 智能保存历史记录（只在数据变化时保存）
    public func saveHistoryIfChanged(scholarId: String, citationCount: Int, timestamp: Date = Date()) {
        let recentHistory = getHistory(for: scholarId, days: 1)
        
        // 检查最近24小时内是否有相同的引用数
        if let latestHistory = recentHistory.last,
           latestHistory.citationCount == citationCount {
            print("📝 [DataManager] 引用数未变化，跳过保存: \(scholarId)")
            return
        }
        
        let newHistory = CitationHistory(scholarId: scholarId, citationCount: citationCount, timestamp: timestamp)
        addHistory(newHistory)
    }
    
    /// 获取指定学者的历史记录
    public func getHistory(for scholarId: String, from startDate: Date? = nil, to endDate: Date? = nil) -> [CitationHistory] {
        let allHistory = getAllHistory()
        var filtered = allHistory.filter { $0.scholarId == scholarId }
        
        if let start = startDate {
            filtered = filtered.filter { $0.timestamp >= start }
        }
        
        if let end = endDate {
            filtered = filtered.filter { $0.timestamp <= end }
        }
        
        return filtered.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// 获取指定学者最近几天的历史记录
    public func getHistory(for scholarId: String, days: Int) -> [CitationHistory] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        return getHistory(for: scholarId, from: startDate, to: endDate)
    }
    
    /// 删除指定学者的所有历史记录
    public func removeAllHistory(for scholarId: String) {
        let allHistory = getAllHistory()
        let filtered = allHistory.filter { $0.scholarId != scholarId }
        saveAllHistory(filtered)
        print("✅ [DataManager] 删除历史记录: \(scholarId)")
    }
    
    /// 清理所有历史记录
    public func clearAllHistory() {
        saveAllHistory([])
        print("✅ [DataManager] 清理所有历史记录")
    }
    
    /// 清理旧数据（保留最近指定天数的数据）
    public func cleanOldHistory(keepDays: Int = 365) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date()) ?? Date()
        let allHistory = getAllHistory()
        let filtered = allHistory.filter { $0.timestamp >= cutoffDate }
        
        saveAllHistory(filtered)
        print("✅ [DataManager] 清理旧历史记录，保留 \(filtered.count) 条记录")
    }
    
    // MARK: - 批量导入
    
    /// 批量导入历史数据
    public func importHistoryData(_ historyList: [CitationHistory]) {
        var allHistory = getAllHistory()
        var importedCount = 0
        
        for history in historyList {
            // 检查是否已存在相同的记录（相同学者+时间戳）
            let exists = allHistory.contains { existing in
                existing.scholarId == history.scholarId &&
                abs(existing.timestamp.timeIntervalSince(history.timestamp)) < 60 // 1分钟内认为是同一条记录
            }
            
            if !exists {
                allHistory.append(history)
                importedCount += 1
            }
        }
        
        saveAllHistory(allHistory)
        print("✅ [DataManager] 导入历史数据: \(importedCount) 条新记录")
    }
    
    /// 批量导入学者和历史数据
    public func importData(scholars: [Scholar], history: [CitationHistory]) {
        // 导入学者
        for scholar in scholars {
            addScholar(scholar)
        }
        
        // 导入历史记录
        importHistoryData(history)
    }
    
    // MARK: - 数据统计
    
    /// 获取数据统计信息
    public func getDataStatistics() -> DataStatistics {
        let allHistory = getAllHistory()
        let historyByScholar = Dictionary(grouping: allHistory) { $0.scholarId }
        
        return DataStatistics(
            totalScholars: scholars.count,
            totalHistoryRecords: allHistory.count,
            scholarsWithHistory: historyByScholar.keys.count,
            oldestRecord: allHistory.min { $0.timestamp < $1.timestamp }?.timestamp,
            newestRecord: allHistory.max { $0.timestamp < $1.timestamp }?.timestamp
        )
    }
    
    /// 计算学者在指定时间段的引用增长量
    public func getCitationGrowth(for scholarId: String, days: Int) -> CitationGrowth? {
        let now = Date()
        let pastDate = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        
        // 获取当前学者信息
        guard let currentScholar = scholars.first(where: { $0.id == scholarId }),
              let currentCitations = currentScholar.citations else {
            return nil
        }
        
        // 获取历史数据
        let history = getHistory(for: scholarId, from: pastDate, to: now)
        
        // 如果没有历史数据，返回0增长
        guard !history.isEmpty else {
            return CitationGrowth(
                scholarId: scholarId,
                period: days,
                currentCitations: currentCitations,
                previousCitations: currentCitations,
                growth: 0,
                growthPercentage: 0.0
            )
        }
        
        // 找到最接近指定时间的历史记录
        let previousRecord = history.first { record in
            abs(record.timestamp.timeIntervalSince(pastDate)) < TimeInterval(days * 24 * 60 * 60 / 2)
        } ?? history.first
        
        let previousCitations = previousRecord?.citationCount ?? currentCitations
        let growth = currentCitations - previousCitations
        let growthPercentage = previousCitations > 0 ? Double(growth) / Double(previousCitations) * 100.0 : 0.0
        
        return CitationGrowth(
            scholarId: scholarId,
            period: days,
            currentCitations: currentCitations,
            previousCitations: previousCitations,
            growth: growth,
            growthPercentage: growthPercentage
        )
    }
    
    /// 获取学者的多时间段增长数据
    public func getMultiPeriodGrowth(for scholarId: String) -> MultiPeriodGrowth? {
        let weeklyGrowth = getCitationGrowth(for: scholarId, days: 7)
        let monthlyGrowth = getCitationGrowth(for: scholarId, days: 30)
        let quarterlyGrowth = getCitationGrowth(for: scholarId, days: 90)
        
        guard let currentScholar = scholars.first(where: { $0.id == scholarId }),
              let currentCitations = currentScholar.citations else {
            return nil
        }
        
        return MultiPeriodGrowth(
            scholarId: scholarId,
            currentCitations: currentCitations,
            weeklyGrowth: weeklyGrowth,
            monthlyGrowth: monthlyGrowth,
            quarterlyGrowth: quarterlyGrowth
        )
    }
}

// MARK: - 数据统计

public struct DataStatistics {
    public let totalScholars: Int
    public let totalHistoryRecords: Int
    public let scholarsWithHistory: Int
    public let oldestRecord: Date?
    public let newestRecord: Date?
    
    public var dataHealthy: Bool {
        return totalScholars > 0 && totalHistoryRecords > 0
    }
}

/// 单一时间段的引用增长数据
public struct CitationGrowth: Codable {
    public let scholarId: String
    public let period: Int  // 天数
    public let currentCitations: Int
    public let previousCitations: Int
    public let growth: Int
    public let growthPercentage: Double
    
    public init(scholarId: String, period: Int, currentCitations: Int, previousCitations: Int, growth: Int, growthPercentage: Double) {
        self.scholarId = scholarId
        self.period = period
        self.currentCitations = currentCitations
        self.previousCitations = previousCitations
        self.growth = growth
        self.growthPercentage = growthPercentage
    }
    
    /// 增长趋势
    public var trend: String {
        if growth > 0 { return "上升" }
        else if growth < 0 { return "下降" }
        else { return "持平" }
    }
}

/// 多时间段的增长数据
public struct MultiPeriodGrowth: Codable {
    public let scholarId: String
    public let currentCitations: Int
    public let weeklyGrowth: CitationGrowth?
    public let monthlyGrowth: CitationGrowth?
    public let quarterlyGrowth: CitationGrowth?
    
    public init(scholarId: String, currentCitations: Int, weeklyGrowth: CitationGrowth?, monthlyGrowth: CitationGrowth?, quarterlyGrowth: CitationGrowth?) {
        self.scholarId = scholarId
        self.currentCitations = currentCitations
        self.weeklyGrowth = weeklyGrowth
        self.monthlyGrowth = monthlyGrowth
        self.quarterlyGrowth = quarterlyGrowth
    }
}

// MARK: - 数据验证

extension DataManager {
    /// 验证数据完整性
    public func validateDataIntegrity() -> DataValidationResult {
        let allHistory = getAllHistory()
        let scholarIds = Set(scholars.map { $0.id })
        let historyScholarIds = Set(allHistory.map { $0.scholarId })
        
        let orphanedHistory = historyScholarIds.subtracting(scholarIds)
        let scholarsWithoutHistory = scholarIds.subtracting(historyScholarIds)
        
        return DataValidationResult(
            totalScholars: scholars.count,
            totalHistory: allHistory.count,
            orphanedHistoryCount: orphanedHistory.count,
            scholarsWithoutHistoryCount: scholarsWithoutHistory.count,
            orphanedScholarIds: Array(orphanedHistory),
            isValid: orphanedHistory.isEmpty
        )
    }
    
    /// 修复数据完整性问题
    public func repairDataIntegrity() {
        let result = validateDataIntegrity()
        
        if !result.orphanedScholarIds.isEmpty {
            // 删除孤立的历史记录
            let allHistory = getAllHistory()
            let validHistory = allHistory.filter { history in
                scholars.contains { $0.id == history.scholarId }
            }
            saveAllHistory(validHistory)
            print("✅ [DataManager] 修复数据完整性: 删除 \(allHistory.count - validHistory.count) 条孤立记录")
        }
    }
}

public struct DataValidationResult {
    public let totalScholars: Int
    public let totalHistory: Int
    public let orphanedHistoryCount: Int
    public let scholarsWithoutHistoryCount: Int
    public let orphanedScholarIds: [String]
    public let isValid: Bool
}