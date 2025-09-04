import Foundation
import WidgetKit

// MARK: - Widget专用数据服务 (简化版)
/// 专门为Widget扩展提供的简化数据服务
/// 避免循环依赖，只包含Widget需要的基本功能
public class WidgetDataService {
    
    public static let shared = WidgetDataService()
    
    private let storage: SimpleWidgetStorage
    
    private init() {
        self.storage = SimpleWidgetStorage()
    }
    
    // MARK: - Widget数据访问
    
    /// 获取Widget数据
    public func getWidgetData() async throws -> WidgetData {
        return try await storage.loadWidgetData()
    }
    
    /// 获取当前选中的学者
    public func getCurrentSelectedScholar() async throws -> WidgetScholarInfo? {
        let data = try await getWidgetData()
        
        guard let selectedId = data.selectedScholarId else {
            return data.scholars.first
        }
        
        return data.scholars.first { $0.id == selectedId }
    }
    
    /// 获取学者列表
    public func getAvailableScholars() async throws -> [WidgetScholarInfo] {
        let data = try await getWidgetData()
        return data.scholars
    }
    
    /// 更新选中的学者
    public func updateSelectedScholar(id: String) async throws {
        await storage.writeValue(id, forKey: "SelectedWidgetScholarId")
        
        // 通知Widget更新
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// 记录刷新动作
    public func recordRefreshAction() async {
        let now = Date()
        await storage.writeValue(now, forKey: "LastRefreshTime")
        await storage.writeValue(now, forKey: "RefreshTriggerTime")
        await storage.writeValue(true, forKey: "RefreshTriggered")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// 记录学者切换动作
    public func recordScholarSwitchAction() async {
        let now = Date()
        await storage.writeValue(now, forKey: "LastScholarSwitchTime")
        await storage.writeValue(true, forKey: "ScholarSwitched")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// 切换到下一个学者
    public func switchToNextScholar() async throws {
        let data = try await getWidgetData()
        
        guard !data.scholars.isEmpty else {
            throw WidgetDataError.noScholarsAvailable
        }
        
        let currentIndex: Int
        if let selectedId = data.selectedScholarId,
           let index = data.scholars.firstIndex(where: { $0.id == selectedId }) {
            currentIndex = index
        } else {
            currentIndex = -1
        }
        
        let nextIndex = (currentIndex + 1) % data.scholars.count
        let nextScholar = data.scholars[nextIndex]
        
        try await updateSelectedScholar(id: nextScholar.id)
        await recordScholarSwitchAction()
    }
}

// MARK: - 简化的存储管理器
private class SimpleWidgetStorage {
    
    private let appGroupDefaults: UserDefaults?
    private let standardDefaults: UserDefaults
    
    init() {
        self.standardDefaults = UserDefaults.standard
        self.appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier)
    }
    
    /// 加载Widget数据
    func loadWidgetData() async throws -> WidgetData {
        // 1. 加载学者数据
        let scholars = try await loadScholars()
        
        // 2. 获取选中的学者ID
        let selectedScholarId = await readValue(forKey: "SelectedWidgetScholarId") as? String
        
        // 3. 计算总引用数
        let totalCitations = scholars.reduce(0) { $0 + $1.citations }
        
        // 4. 获取最后更新时间
        let lastUpdateTime = await readValue(forKey: "LastRefreshTime") as? Date
        
        return WidgetData(
            scholars: scholars,
            selectedScholarId: selectedScholarId,
            totalCitations: totalCitations,
            lastUpdateTime: lastUpdateTime
        )
    }
    
    /// 加载学者数据
    private func loadScholars() async throws -> [WidgetScholarInfo] {
        // 尝试从App Group读取
        if let appGroupDefaults = appGroupDefaults,
           let data = appGroupDefaults.data(forKey: "ScholarsList"),
           let scholars = try? JSONDecoder().decode([Scholar].self, from: data) {
            return scholars.map { scholar in
                WidgetScholarInfo(
                    id: scholar.id,
                    name: scholar.name,
                    citations: scholar.citations ?? 0,
                    lastUpdated: scholar.lastUpdated ?? Date()
                )
            }
        }
        
        // 回退到标准UserDefaults
        if let data = standardDefaults.data(forKey: "ScholarsList"),
           let scholars = try? JSONDecoder().decode([Scholar].self, from: data) {
            return scholars.map { scholar in
                WidgetScholarInfo(
                    id: scholar.id,
                    name: scholar.name,
                    citations: scholar.citations ?? 0,
                    lastUpdated: scholar.lastUpdated ?? Date()
                )
            }
        }
        
        return []
    }
    
    /// 读取值
    func readValue(forKey key: String) async -> Any? {
        // 优先从App Group读取
        if let appGroupDefaults = appGroupDefaults {
            if let value = appGroupDefaults.object(forKey: key) {
                return value
            }
        }
        
        // 回退到标准UserDefaults
        return standardDefaults.object(forKey: key)
    }
    
    /// 写入值
    func writeValue(_ value: Any, forKey key: String) async {
        // 写入标准UserDefaults
        standardDefaults.set(value, forKey: key)
        
        // 如果App Group可用，也写入App Group
        if let appGroupDefaults = appGroupDefaults {
            appGroupDefaults.set(value, forKey: key)
            appGroupDefaults.synchronize()
        }
    }
}

// MARK: - 支持类型

/// 简化的Scholar模型 (用于解码)
private struct Scholar: Codable {
    let id: String
    let name: String
    let citations: Int?
    let lastUpdated: Date?
}

/// Widget数据错误
public enum WidgetDataError: Error, LocalizedError {
    case noScholarsAvailable
    case loadingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noScholarsAvailable:
            return "没有可用的学者数据"
        case .loadingFailed(let message):
            return "数据加载失败: \(message)"
        }
    }
}
