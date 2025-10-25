import Foundation
import Cocoa

// MARK: - Citation History Model (与iOS完全兼容)
public struct CitationHistoryData: Codable, Identifiable, Equatable {
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

// MARK: - 统一的数据管理器 (与iOS DataManager兼容)
public class DataManager: ObservableObject {
    public static let shared = DataManager()
    
    private let userDefaults = UserDefaults.standard
    private let scholarsKey = "ScholarsList"
    private let historyKey = "CitationHistoryData"
    
    // 发布的数据
    @Published var scholars: [Scholar] = []
    @Published public var lastRefreshTime: Date? = nil
    
    private init() {
        print("🔍 [DataManager] 初始化 macOS DataManager...")
        loadScholars()
        
        // 加载上次刷新时间
        if let t = userDefaults.object(forKey: "LastRefreshTime") as? Date {
            lastRefreshTime = t
            print("🧪 [DataManager] 读取上次刷新时间: \(t)")
        }
        
        print("🔄 [DataManager] 初始化完成，已加载 \(scholars.count) 位学者")
    }
    
    // MARK: - 学者管理
    
    /// 加载所有学者
    public func loadScholars() {
        if let data = userDefaults.data(forKey: scholarsKey),
           let decodedScholars = try? JSONDecoder().decode([Scholar].self, from: data) {
            scholars = decodedScholars
            print("✅ [DataManager] 加载了 \(scholars.count) 位学者")
        } else {
            scholars = []
            print("ℹ️ [DataManager] 没有找到已保存的学者数据")
        }
    }
    
    /// 保存所有学者
    private func saveScholars() {
        if let encoded = try? JSONEncoder().encode(scholars) {
            userDefaults.set(encoded, forKey: scholarsKey)
            print("✅ [DataManager] 已保存 \(scholars.count) 位学者")
        }
    }
    
    /// 添加学者（自动去重）
    func addScholar(_ scholar: Scholar) {
        if !scholars.contains(where: { $0.id == scholar.id }) {
            scholars.append(scholar)
            saveScholars()
            print("✅ [DataManager] 添加了学者: \(scholar.name)")
        } else {
            print("⚠️ [DataManager] 学者已存在: \(scholar.name)")
        }
    }
    
    /// 更新学者信息
    func updateScholar(_ scholar: Scholar) {
        if let index = scholars.firstIndex(where: { $0.id == scholar.id }) {
            scholars[index] = scholar
            saveScholars()
            print("✅ [DataManager] 更新了学者: \(scholar.name)")
        } else {
            addScholar(scholar)
        }
    }
    
    /// 删除学者
    public func removeScholar(id: String) {
        scholars.removeAll { $0.id == id }
        saveScholars()
        removeAllHistory(for: id)
        print("✅ [DataManager] 删除了学者: \(id)")
    }
    
    /// 删除所有学者
    public func removeAllScholars() {
        scholars.removeAll()
        saveScholars()
        clearAllHistory()
        print("✅ [DataManager] 已删除所有学者")
    }
    
    /// 获取学者信息
    func getScholar(id: String) -> Scholar? {
        return scholars.first { $0.id == id }
    }
    
    // MARK: - 历史记录管理
    
    /// 获取所有历史记录
    private func getAllHistory() -> [CitationHistoryData] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([CitationHistoryData].self, from: data) else {
            return []
        }
        return history
    }
    
    /// 保存所有历史记录
    private func saveAllHistory(_ history: [CitationHistoryData]) {
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
    
    /// 添加历史记录
    public func addHistory(_ history: CitationHistoryData) {
        var allHistory = getAllHistory()
        allHistory.append(history)
        saveAllHistory(allHistory)
        print("✅ [DataManager] 保存了历史记录: \(history.scholarId) - \(history.citationCount)")
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
        
        let newHistory = CitationHistoryData(scholarId: scholarId, citationCount: citationCount, timestamp: timestamp)
        addHistory(newHistory)
    }
    
    /// 获取指定学者的历史记录
    public func getHistory(for scholarId: String, from startDate: Date? = nil, to endDate: Date? = nil) -> [CitationHistoryData] {
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
    public func getHistory(for scholarId: String, days: Int) -> [CitationHistoryData] {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        return getHistory(for: scholarId, from: startDate, to: endDate)
    }
    
    /// 删除指定学者的所有历史记录
    public func removeAllHistory(for scholarId: String) {
        let allHistory = getAllHistory()
        let filtered = allHistory.filter { $0.scholarId != scholarId }
        saveAllHistory(filtered)
        print("✅ [DataManager] 删除了学者的历史记录: \(scholarId)")
    }
    
    /// 清理所有历史记录
    public func clearAllHistory() {
        saveAllHistory([])
        print("✅ [DataManager] 已清理所有历史记录")
    }
    
    /// 清理旧数据（保留最近指定天数的数据）
    public func cleanOldHistory(keepDays: Int = 365) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date()) ?? Date()
        let allHistory = getAllHistory()
        let filtered = allHistory.filter { $0.timestamp >= cutoffDate }
        
        saveAllHistory(filtered)
        print("✅ [DataManager] 清理旧数据，保留了 \(filtered.count) 条记录")
    }
    
    // MARK: - 批量导入导出（与iOS兼容）
    
    /// 从iOS导出的JSON文件导入数据
    public func importFromiOSData(jsonData: Data) throws -> (importedScholars: Int, importedHistory: Int) {
        // 尝试解析为历史记录数组格式（citation_data.json）
        if let historyArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
            return try importFromHistoryArray(historyArray)
        }
        
        // 尝试解析为统一格式
        if let dict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            return try importFromUnifiedFormat(dict)
        }
        
        throw NSError(domain: "DataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析导入文件格式"])
    }
    
    /// 从历史记录数组格式导入（citation_data.json）
    private func importFromHistoryArray(_ historyArray: [[String: Any]]) throws -> (importedScholars: Int, importedHistory: Int) {
        var importedScholars = 0
        var importedHistory = 0
        var scholarMap: [String: Scholar] = [:]
        var historyList: [CitationHistoryData] = []
        
        let formatter = ISO8601DateFormatter()
        
        for entry in historyArray {
            guard let scholarId = entry["scholarId"] as? String,
                  let scholarName = entry["scholarName"] as? String,
                  let timestampStr = entry["timestamp"] as? String,
                  let citationCount = entry["citationCount"] as? Int,
                  let timestamp = formatter.date(from: timestampStr) else {
                continue
            }
            
            // 创建或更新学者
            if scholarMap[scholarId] == nil {
                var scholar = Scholar(id: scholarId, name: scholarName)
                scholar.citations = citationCount
                scholar.lastUpdated = timestamp
                scholarMap[scholarId] = scholar
            } else {
                // 更新为最新的引用数
                if var scholar = scholarMap[scholarId],
                   let lastUpdate = scholar.lastUpdated,
                   timestamp > lastUpdate {
                    scholar.citations = citationCount
                    scholar.lastUpdated = timestamp
                    scholarMap[scholarId] = scholar
                }
            }
            
            // 创建历史记录
            let history = CitationHistoryData(scholarId: scholarId, citationCount: citationCount, timestamp: timestamp)
            historyList.append(history)
        }
        
        // 导入学者
        for scholar in scholarMap.values {
            addScholar(scholar)
            importedScholars += 1
        }
        
        // 导入历史记录
        importHistoryData(historyList)
        importedHistory = historyList.count
        
        print("✅ [DataManager] 从iOS数据导入: \(importedScholars) 位学者, \(importedHistory) 条历史记录")
        return (importedScholars, importedHistory)
    }
    
    /// 从统一格式导入
    private func importFromUnifiedFormat(_ dict: [String: Any]) throws -> (importedScholars: Int, importedHistory: Int) {
        var importedScholars = 0
        var importedHistory = 0
        
        // 导入学者列表
        if let scholarsArray = dict["scholars"] as? [[String: Any]] {
            for scholarDict in scholarsArray {
                guard let id = scholarDict["id"] as? String,
                      let name = scholarDict["name"] as? String else {
                    continue
                }
                
                var scholar = Scholar(id: id, name: name)
                if let citations = scholarDict["citations"] as? Int {
                    scholar.citations = citations
                }
                if let lastUpdatedStr = scholarDict["lastUpdated"] as? String {
                    let formatter = ISO8601DateFormatter()
                    scholar.lastUpdated = formatter.date(from: lastUpdatedStr)
                }
                
                addScholar(scholar)
                importedScholars += 1
            }
        }
        
        // 导入历史记录
        if let historyArray = dict["citationHistory"] as? [[String: Any]] {
            let result = try importFromHistoryArray(historyArray)
            importedHistory = result.importedHistory
        }
        
        print("✅ [DataManager] 从统一格式导入: \(importedScholars) 位学者, \(importedHistory) 条历史记录")
        return (importedScholars, importedHistory)
    }
    
    /// 批量导入历史数据
    public func importHistoryData(_ historyList: [CitationHistoryData]) {
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
        print("✅ [DataManager] 导入了 \(importedCount) 条历史记录")
    }
    
    /// 导出为iOS兼容的JSON格式
    public func exportToiOSFormat() throws -> Data {
        let formatter = ISO8601DateFormatter()
        var exportEntries: [[String: Any]] = []
        
        for scholar in scholars {
            let histories = getHistory(for: scholar.id)
            if histories.isEmpty {
                if let citations = scholar.citations {
                    let ts = scholar.lastUpdated ?? Date()
                    exportEntries.append([
                        "scholarId": scholar.id,
                        "scholarName": scholar.name,
                        "timestamp": formatter.string(from: ts),
                        "citationCount": citations
                    ])
                }
            } else {
                for h in histories {
                    exportEntries.append([
                        "scholarId": scholar.id,
                        "scholarName": scholar.name,
                        "timestamp": formatter.string(from: h.timestamp),
                        "citationCount": h.citationCount
                    ])
                }
            }
        }
        
        return try JSONSerialization.data(withJSONObject: exportEntries, options: .prettyPrinted)
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
        
        guard let currentScholar = scholars.first(where: { $0.id == scholarId }),
              let currentCitations = currentScholar.citations else {
            return nil
        }
        
        let history = getHistory(for: scholarId, from: pastDate, to: now)
        
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
        
        let previousRecord = history.first
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
    public let period: Int
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
    
    public var trend: String {
        if growth > 0 { return "上升" }
        else if growth < 0 { return "下降" }
        else { return "持平" }
    }
}

