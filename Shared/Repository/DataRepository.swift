import Foundation
import Combine
#if os(iOS)
import WidgetKit
#endif

// MARK: - 数据仓库实现
/// 统一的数据访问实现，负责所有数据操作的协调和管理
public class DataRepository: DataRepositoryProtocol, ObservableObject {
    
    // MARK: - Properties
    
    public static let shared = DataRepository()
    
    private let storage: UnifiedDataStorage
    private let dataQueue = DispatchQueue(label: "com.citetrack.data.repository", qos: .userInitiated)
    
    // Publishers for data observation
    private let scholarsSubject = CurrentValueSubject<[Scholar], Never>([])
    private let widgetDataSubject = CurrentValueSubject<WidgetData, Never>(
        WidgetData(scholars: [], selectedScholarId: nil, totalCitations: 0, lastUpdateTime: nil)
    )
    private let syncStatusSubject = CurrentValueSubject<DataSyncStatus, Never>(.idle)
    
    // Cache for frequently accessed data
    private var scholarsCache: [Scholar] = []
    private var citationHistoryCache: [String: [CitationHistory]] = [:]
    private var lastCacheUpdate: Date = .distantPast
    private let cacheValidityDuration: TimeInterval = 300 // 5分钟缓存有效期
    
    // MARK: - Initialization
    
    private init() {
        self.storage = UnifiedDataStorage()
        
        // 初始化时加载数据
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Publishers
    
    public var scholarsPublisher: AnyPublisher<[Scholar], Never> {
        scholarsSubject.eraseToAnyPublisher()
    }
    
    public var widgetDataPublisher: AnyPublisher<WidgetData, Never> {
        widgetDataSubject.eraseToAnyPublisher()
    }
    
    public var syncStatusPublisher: AnyPublisher<DataSyncStatus, Never> {
        syncStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 初始数据加载
    
    private func loadInitialData() async {
        do {
            // 加载学者数据
            let scholars = try await fetchScholars()
            await MainActor.run {
                self.scholarsSubject.send(scholars)
            }
            
            // 加载Widget数据
            let widgetData = try await fetchWidgetData()
            await MainActor.run {
                self.widgetDataSubject.send(widgetData)
            }
            
            print("✅ [DataRepository] 初始数据加载完成")
        } catch {
            print("❌ [DataRepository] 初始数据加载失败: \(error)")
        }
    }
    
    // MARK: - 学者数据管理
    
    public func fetchScholars() async throws -> [Scholar] {
        // 检查缓存
        if isCacheValid() && !scholarsCache.isEmpty {
            print("🔄 [DataRepository] 使用缓存的学者数据")
            return scholarsCache
        }
        
        // 从存储读取
        let scholars = try await storage.readData([Scholar].self, forKey: UnifiedDataStorage.Keys.scholars) ?? []
        
        // 更新缓存
        scholarsCache = scholars
        lastCacheUpdate = Date()
        
        print("✅ [DataRepository] 加载学者数据: \(scholars.count)个")
        return scholars
    }
    
    public func fetchScholar(id: String) async throws -> Scholar? {
        let scholars = try await fetchScholars()
        return scholars.first { $0.id == id }
    }
    
    public func saveScholar(_ scholar: Scholar) async throws {
        var scholars = try await fetchScholars()
        
        // 检查是否已存在
        if let existingIndex = scholars.firstIndex(where: { $0.id == scholar.id }) {
            scholars[existingIndex] = scholar
        } else {
            scholars.append(scholar)
        }
        
        // 保存到存储
        try await storage.writeData(scholars, forKey: UnifiedDataStorage.Keys.scholars)
        
        // 更新缓存和发布者
        scholarsCache = scholars
        lastCacheUpdate = Date()
        
        await MainActor.run {
            self.scholarsSubject.send(scholars)
        }
        
        // 同步Widget数据
        try await updateWidgetDataAfterScholarChange()
        
        print("✅ [DataRepository] 保存学者: \(scholar.displayName)")
    }
    
    public func updateScholar(_ scholar: Scholar) async throws {
        try await saveScholar(scholar)
    }
    
    public func deleteScholar(id: String) async throws {
        var scholars = try await fetchScholars()
        scholars.removeAll { $0.id == id }
        
        // 保存到存储
        try await storage.writeData(scholars, forKey: UnifiedDataStorage.Keys.scholars)
        
        // 删除相关的引用历史
        try await deleteCitationHistory(for: id)
        
        // 更新缓存和发布者
        scholarsCache = scholars
        lastCacheUpdate = Date()
        
        await MainActor.run {
            self.scholarsSubject.send(scholars)
        }
        
        // 同步Widget数据
        try await updateWidgetDataAfterScholarChange()
        
        print("✅ [DataRepository] 删除学者: \(id)")
    }
    
    public func deleteAllScholars() async throws {
        // 清空学者数据
        try await storage.writeData([Scholar](), forKey: UnifiedDataStorage.Keys.scholars)
        
        // 清空所有引用历史
        try await deleteAllCitationHistory()
        
        // 更新缓存和发布者
        scholarsCache = []
        citationHistoryCache = [:]
        lastCacheUpdate = Date()
        
        await MainActor.run {
            self.scholarsSubject.send([])
        }
        
        // 同步Widget数据
        try await updateWidgetDataAfterScholarChange()
        
        print("✅ [DataRepository] 删除所有学者")
    }
    
    // MARK: - 引用历史管理
    
    public func fetchCitationHistory(for scholarId: String, from startDate: Date?, to endDate: Date?) async throws -> [CitationHistory] {
        // 检查缓存
        if let cachedHistory = citationHistoryCache[scholarId], isCacheValid() {
            return filterHistory(cachedHistory, from: startDate, to: endDate)
        }
        
        // 从存储读取所有历史
        let allHistory = try await fetchAllCitationHistory()
        
        // 筛选指定学者的历史
        let scholarHistory = allHistory.filter { $0.scholarId == scholarId }
        
        // 更新缓存
        citationHistoryCache[scholarId] = scholarHistory
        
        return filterHistory(scholarHistory, from: startDate, to: endDate)
    }
    
    public func fetchAllCitationHistory() async throws -> [CitationHistory] {
        return try await storage.readData([CitationHistory].self, forKey: UnifiedDataStorage.Keys.citationHistory) ?? []
    }
    
    public func saveCitationHistory(_ history: CitationHistory) async throws {
        var allHistory = try await fetchAllCitationHistory()
        allHistory.append(history)
        
        // 保存到存储
        try await storage.writeData(allHistory, forKey: UnifiedDataStorage.Keys.citationHistory)
        
        // 更新缓存
        var scholarHistory = citationHistoryCache[history.scholarId] ?? []
        scholarHistory.append(history)
        citationHistoryCache[history.scholarId] = scholarHistory
        
        // 通知Widget更新
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        print("✅ [DataRepository] 保存引用历史: \(history.scholarId) - \(history.citationCount)")
    }
    
    public func deleteCitationHistory(for scholarId: String) async throws {
        var allHistory = try await fetchAllCitationHistory()
        allHistory.removeAll { $0.scholarId == scholarId }
        
        // 保存到存储
        try await storage.writeData(allHistory, forKey: UnifiedDataStorage.Keys.citationHistory)
        
        // 更新缓存
        citationHistoryCache[scholarId] = []
        
        print("✅ [DataRepository] 删除学者引用历史: \(scholarId)")
    }
    
    public func deleteAllCitationHistory() async throws {
        try await storage.writeData([CitationHistory](), forKey: UnifiedDataStorage.Keys.citationHistory)
        citationHistoryCache = [:]
        print("✅ [DataRepository] 删除所有引用历史")
    }
    
    // MARK: - Widget数据管理
    
    public func fetchWidgetData() async throws -> WidgetData {
        let scholars = try await fetchScholars()
        let selectedScholarId = await storage.readValue(forKey: UnifiedDataStorage.Keys.selectedScholarId) as? String

        // 并发计算每位学者的7/30/90天增长
        let widgetScholars: [WidgetScholarInfo] = try await withThrowingTaskGroup(of: WidgetScholarInfo.self) { group in
            for scholar in scholars {
                group.addTask { [weak self] in
                    let current = scholar.citations ?? 0
                    let weekly = try await self?.fetchCitationGrowth(for: scholar.id, days: 7)?.growth
                    let monthly = try await self?.fetchCitationGrowth(for: scholar.id, days: 30)?.growth
                    let quarterly = try await self?.fetchCitationGrowth(for: scholar.id, days: 90)?.growth
                    return WidgetScholarInfo(
                        id: scholar.id,
                        name: scholar.name,
                        citations: current,
                        lastUpdated: scholar.lastUpdated ?? Date(),
                        weeklyGrowth: weekly,
                        monthlyGrowth: monthly,
                        quarterlyGrowth: quarterly
                    )
                }
            }

            var results: [WidgetScholarInfo] = []
            for try await item in group {
                results.append(item)
            }
            return results
        }

        // 将包含增长的数据写入统一存储，供Widget直接读取与App Group同步
        try await storage.writeData(widgetScholars, forKey: UnifiedDataStorage.Keys.widgetScholars)

        let totalCitations = scholars.compactMap { $0.citations }.reduce(0, +)
        let lastUpdateTime = await storage.readValue(forKey: UnifiedDataStorage.Keys.lastRefreshTime) as? Date

        let result = WidgetData(
            scholars: widgetScholars,
            selectedScholarId: selectedScholarId,
            totalCitations: totalCitations,
            lastUpdateTime: lastUpdateTime
        )
        print("🧪 [DataRepository] fetchWidgetData: scholars=\(widgetScholars.count), lastUpdateTime=\(lastUpdateTime?.description ?? "nil")")
        return result
    }
    
    public func updateWidgetData(_ data: WidgetData) async throws {
        // 更新选中的学者
        if let selectedId = data.selectedScholarId {
            await storage.writeValue(selectedId, forKey: UnifiedDataStorage.Keys.selectedScholarId)
        }
        
        // 更新最后刷新时间
        if let lastUpdate = data.lastUpdateTime {
            await storage.writeValue(lastUpdate, forKey: UnifiedDataStorage.Keys.lastRefreshTime)
        }
        
        // 保存Widget学者数据（用于Widget快速访问）
        try await storage.writeData(data.scholars, forKey: UnifiedDataStorage.Keys.widgetScholars)
        
        // 发布更新
        await MainActor.run {
            print("🧪 [DataRepository] updateWidgetData 发布: lastUpdateTime=\(data.lastUpdateTime?.description ?? "nil")")
            self.widgetDataSubject.send(data)
        }
        
        // 通知Widget更新
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        print("✅ [DataRepository] 更新Widget数据")
    }
    
    public func getCurrentSelectedScholarId() async throws -> String? {
        return await storage.readValue(forKey: UnifiedDataStorage.Keys.selectedScholarId) as? String
    }
    
    public func setCurrentSelectedScholar(id: String) async throws {
        await storage.writeValue(id, forKey: UnifiedDataStorage.Keys.selectedScholarId)
        
        // 更新Widget数据
        let widgetData = try await fetchWidgetData()
        await MainActor.run {
            self.widgetDataSubject.send(widgetData)
        }
        
        print("✅ [DataRepository] 设置选中学者: \(id)")
    }
    
    // MARK: - 数据统计
    
    public func fetchDataStatistics() async throws -> DataStatistics {
        let scholars = try await fetchScholars()
        let allHistory = try await fetchAllCitationHistory()
        let historyByScholar = Dictionary(grouping: allHistory) { $0.scholarId }
        
        return DataStatistics(
            totalScholars: scholars.count,
            totalHistoryRecords: allHistory.count,
            scholarsWithHistory: historyByScholar.keys.count,
            oldestRecord: allHistory.min { $0.timestamp < $1.timestamp }?.timestamp,
            newestRecord: allHistory.max { $0.timestamp < $1.timestamp }?.timestamp
        )
    }
    
    public func fetchCitationGrowth(for scholarId: String, days: Int) async throws -> CitationGrowth? {
        guard let scholar = try await fetchScholar(id: scholarId),
              let currentCitations = scholar.citations else {
            return nil
        }
        
        let now = Date()
        let pastDate = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        
        let history = try await fetchCitationHistory(for: scholarId, from: pastDate, to: now)
        
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
    
    public func fetchMultiPeriodGrowth(for scholarId: String) async throws -> MultiPeriodGrowth? {
        guard let scholar = try await fetchScholar(id: scholarId),
              let currentCitations = scholar.citations else {
            return nil
        }
        
        let weeklyGrowth = try await fetchCitationGrowth(for: scholarId, days: 7)
        let monthlyGrowth = try await fetchCitationGrowth(for: scholarId, days: 30)
        let quarterlyGrowth = try await fetchCitationGrowth(for: scholarId, days: 90)
        
        return MultiPeriodGrowth(
            scholarId: scholarId,
            currentCitations: currentCitations,
            weeklyGrowth: weeklyGrowth,
            monthlyGrowth: monthlyGrowth,
            quarterlyGrowth: quarterlyGrowth
        )
    }
    
    // MARK: - 数据同步与一致性
    
    public func syncToAppGroup() async throws {
        syncStatusSubject.send(.syncing)
        
        do {
            let keys = [
                UnifiedDataStorage.Keys.scholars,
                UnifiedDataStorage.Keys.citationHistory,
                UnifiedDataStorage.Keys.widgetScholars,
                UnifiedDataStorage.Keys.selectedScholarId,
                UnifiedDataStorage.Keys.lastRefreshTime
            ]
            
            try await storage.syncToAppGroup(keys: keys)
            
            syncStatusSubject.send(.success(Date()))
            print("✅ [DataRepository] 同步到App Group成功")
        } catch {
            syncStatusSubject.send(.failure(error.localizedDescription))
            throw error
        }
    }
    
    public func syncFromAppGroup() async throws {
        syncStatusSubject.send(.syncing)
        
        do {
            let keys = [
                UnifiedDataStorage.Keys.scholars,
                UnifiedDataStorage.Keys.citationHistory,
                UnifiedDataStorage.Keys.widgetScholars,
                UnifiedDataStorage.Keys.selectedScholarId,
                UnifiedDataStorage.Keys.lastRefreshTime
            ]
            
            try await storage.syncFromAppGroup(keys: keys)
            
            // 重新加载数据
            await loadInitialData()
            
            syncStatusSubject.send(.success(Date()))
            print("✅ [DataRepository] 从App Group同步成功")
        } catch {
            syncStatusSubject.send(.failure(error.localizedDescription))
            throw error
        }
    }
    
    public func validateDataIntegrity() async throws -> DataValidationResult {
        let scholars = try await fetchScholars()
        let allHistory = try await fetchAllCitationHistory()
        
        let scholarIds = Set(scholars.map { $0.id })
        let historyScholarIds = Set(allHistory.map { $0.scholarId })
        
        let orphanedHistory = historyScholarIds.subtracting(scholarIds)
        let scholarsWithoutHistory = scholarIds.subtracting(historyScholarIds)
        
        var issues: [String] = []
        var fixableIssues: [String] = []
        
        if !orphanedHistory.isEmpty {
            let issue = "发现\(orphanedHistory.count)个孤立的引用历史记录"
            issues.append(issue)
            fixableIssues.append(issue)
        }
        
        // 检查App Group一致性
        let keys = [UnifiedDataStorage.Keys.scholars, UnifiedDataStorage.Keys.citationHistory]
        let consistencyResults = await storage.validateConsistency(for: keys)
        
        let inconsistentKeys = consistencyResults.filter { !$0.value }.map { $0.key }
        if !inconsistentKeys.isEmpty {
            let issue = "App Group数据不一致: \(inconsistentKeys.joined(separator: ", "))"
            issues.append(issue)
            fixableIssues.append(issue)
        }
        
        return DataValidationResult(
            isValid: issues.isEmpty,
            issues: issues,
            fixableIssues: fixableIssues
        )
    }
    
    public func repairDataIntegrity() async throws {
        let result = try await validateDataIntegrity()
        
        if !result.isValid {
            // 修复孤立的历史记录
            let scholars = try await fetchScholars()
            let allHistory = try await fetchAllCitationHistory()
            let scholarIds = Set(scholars.map { $0.id })
            
            let validHistory = allHistory.filter { scholarIds.contains($0.scholarId) }
            try await storage.writeData(validHistory, forKey: UnifiedDataStorage.Keys.citationHistory)
            
            // 同步到App Group
            try await syncToAppGroup()
            
            print("✅ [DataRepository] 数据完整性修复完成")
        }
    }
    
    // MARK: - 私有辅助方法
    
    private func isCacheValid() -> Bool {
        return Date().timeIntervalSince(lastCacheUpdate) < cacheValidityDuration
    }
    
    private func filterHistory(_ history: [CitationHistory], from startDate: Date?, to endDate: Date?) -> [CitationHistory] {
        var filteredHistory = history
        
        if let start = startDate {
            filteredHistory = filteredHistory.filter { $0.timestamp >= start }
        }
        
        if let end = endDate {
            filteredHistory = filteredHistory.filter { $0.timestamp <= end }
        }
        
        return filteredHistory.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func updateWidgetDataAfterScholarChange() async throws {
        let widgetData = try await fetchWidgetData()
        await MainActor.run {
            self.widgetDataSubject.send(widgetData)
        }
        
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
