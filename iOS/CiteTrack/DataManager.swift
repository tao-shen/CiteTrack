import Foundation

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

/// 学者信息
public struct ScholarInfo: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var citations: Int?
    public var lastUpdated: Date?
    
    public init(id: String, name: String = "", citations: Int? = nil, lastUpdated: Date? = nil) {
        self.id = id
        self.name = name.isEmpty ? "学者 \(id.prefix(8))" : name
        self.citations = citations
        self.lastUpdated = lastUpdated
    }
    
    public var displayName: String {
        return name.isEmpty ? "学者 \(id.prefix(8))" : name
    }
    
    public var isDataAvailable: Bool {
        return citations != nil && lastUpdated != nil
    }
}

extension ScholarInfo {
    public var citationDisplay: String {
        guard let citations = citations else { return "未知" }
        return "\(citations)"
    }
}

// MARK: - 数据管理器

/// 统一的数据管理器
public class DataManager: ObservableObject {
    public static let shared = DataManager()
    
    private let userDefaults = UserDefaults.standard
    private let scholarsKey = "ScholarsList"
    private let historyKey = "CitationHistoryData"
    
    // 发布的数据
    @Published public var scholars: [ScholarInfo] = []
    
    private init() {
        loadScholars()
    }
    
    // MARK: - 学者管理
    
    /// 加载所有学者
    public func loadScholars() {
        if let data = userDefaults.data(forKey: scholarsKey),
           let decodedScholars = try? JSONDecoder().decode([ScholarInfo].self, from: data) {
            scholars = decodedScholars
        } else {
            scholars = []
        }
    }
    
    /// 保存所有学者
    private func saveScholars() {
        if let encoded = try? JSONEncoder().encode(scholars) {
            userDefaults.set(encoded, forKey: scholarsKey)
        }
    }
    
    /// 添加学者（自动去重）
    public func addScholar(_ scholar: ScholarInfo) {
        if !scholars.contains(where: { $0.id == scholar.id }) {
            scholars.append(scholar)
            saveScholars()
            print("✅ [DataManager] 添加学者: \(scholar.displayName)")
        } else {
            print("⚠️ [DataManager] 学者已存在: \(scholar.displayName)")
        }
    }
    
    /// 更新学者信息
    public func updateScholar(_ scholar: ScholarInfo) {
        if let index = scholars.firstIndex(where: { $0.id == scholar.id }) {
            scholars[index] = scholar
            saveScholars()
            print("✅ [DataManager] 更新学者: \(scholar.displayName)")
        } else {
            // 如果不存在则添加
            addScholar(scholar)
        }
    }
    
    /// 删除学者
    public func removeScholar(id: String) {
        scholars.removeAll { $0.id == id }
        saveScholars()
        
        // 同时删除相关历史记录
        removeAllHistory(for: id)
        print("✅ [DataManager] 删除学者: \(id)")
    }
    
    /// 删除所有学者
    public func removeAllScholars() {
        scholars.removeAll()
        saveScholars()
        
        // 同时清理所有历史记录
        clearAllHistory()
        print("✅ [DataManager] 删除所有学者")
    }
    
    /// 获取学者信息
    public func getScholar(id: String) -> ScholarInfo? {
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
    public func importData(scholars: [ScholarInfo], history: [CitationHistory]) {
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