import Foundation
import Combine
#if os(iOS)
import WidgetKit
#endif

// MARK: - Widget数据服务
/// 专门为Widget提供数据访问的服务
/// 确保Widget和主应用数据的一致性和高效性
public class WidgetDataService: ObservableObject {
    
    // MARK: - Properties
    
    public static let shared = WidgetDataService()
    
    private let storage: UnifiedDataStorage
    private let dataQueue = DispatchQueue(label: "com.citetrack.widget.data", qos: .userInitiated)
    
    // 缓存机制
    private var cachedWidgetData: WidgetData?
    private var lastCacheTime: Date = .distantPast
    private let cacheValidityDuration: TimeInterval = 60 // 1分钟缓存
    
    // 小组件主题（独立于主App）使用共享模型中的 WidgetTheme
    
    // 发布者
    private let dataUpdateSubject = PassthroughSubject<WidgetData, Never>()
    
    // MARK: - Initialization
    
    private init() {
        self.storage = UnifiedDataStorage()
        print("✅ [WidgetDataService] 初始化完成")
    }
    
    // MARK: - 数据访问
    
    /// 获取Widget数据（优化了性能）
    public func getWidgetData() async throws -> WidgetData {
        // 检查缓存
        if let cachedData = cachedWidgetData, isCacheValid() {
            print("🔄 [WidgetDataService] 使用缓存数据")
            return cachedData
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            dataQueue.async {
                Task {
                    do {
                        let data = try await self.loadWidgetDataFromStorage()
                        
                        // 更新缓存
                        self.cachedWidgetData = data
                        self.lastCacheTime = Date()
                        
                        print("✅ [WidgetDataService] 加载Widget数据成功")
                        continuation.resume(returning: data)
                    } catch {
                        print("❌ [WidgetDataService] 加载Widget数据失败: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// 从存储加载Widget数据
    private func loadWidgetDataFromStorage() async throws -> WidgetData {
        // 1. 优先加载已计算好的Widget学者数据（包含增长），无则回退到原始学者数据转换
        let precomputedWidgetScholars = try await storage.readData([WidgetScholarInfo].self, forKey: UnifiedDataStorage.Keys.widgetScholars)
        let widgetScholars: [WidgetScholarInfo]
        if let precomputed = precomputedWidgetScholars, !precomputed.isEmpty {
            widgetScholars = precomputed
        } else {
            let scholars = try await storage.readData([Scholar].self, forKey: UnifiedDataStorage.Keys.scholars) ?? []
            widgetScholars = scholars.map { scholar in
                WidgetScholarInfo(
                    id: scholar.id,
                    name: scholar.name,
                    citations: scholar.citations ?? 0,
                    lastUpdated: scholar.lastUpdated ?? Date()
                )
            }
        }
        
        // 3. 获取选中的学者ID
        let selectedScholarId = await storage.readValue(forKey: UnifiedDataStorage.Keys.selectedScholarId) as? String
        
        // 4. 计算总引用数
        let totalCitations = scholars.compactMap { $0.citations }.reduce(0, +)
        
        // 5. 获取最后更新时间
        let lastUpdateTime = await storage.readValue(forKey: UnifiedDataStorage.Keys.lastRefreshTime) as? Date
        
        return WidgetData(
            scholars: widgetScholars,
            selectedScholarId: selectedScholarId,
            totalCitations: totalCitations,
            lastUpdateTime: lastUpdateTime
        )
    }

    // MARK: - Widget 主题读写
    public func getWidgetTheme() async -> WidgetTheme {
        if let raw = await storage.readValue(forKey: UnifiedDataStorage.Keys.widgetTheme) as? String,
           let theme = WidgetTheme(rawValue: raw) {
            return theme
        }
        return .system
    }
    
    public func setWidgetTheme(_ theme: WidgetTheme) async {
        await storage.writeValue(theme.rawValue, forKey: UnifiedDataStorage.Keys.widgetTheme)
        await notifyWidgetUpdate()
    }
    
    /// 获取当前选中的学者数据
    public func getCurrentSelectedScholar() async throws -> WidgetScholarInfo? {
        let data = try await getWidgetData()
        
        guard let selectedId = data.selectedScholarId else {
            return data.scholars.first // 如果没有选中的，返回第一个
        }
        
        return data.scholars.first { $0.id == selectedId }
    }
    
    /// 获取学者列表（用于Widget配置）
    public func getAvailableScholars() async throws -> [WidgetScholarInfo] {
        let data = try await getWidgetData()
        return data.scholars
    }
    
    // MARK: - 数据更新
    
    /// 更新选中的学者
    public func updateSelectedScholar(id: String) async throws {
        // 更新存储
        await storage.writeValue(id, forKey: UnifiedDataStorage.Keys.selectedScholarId)
        
        // 获取学者姓名（用于显示）
        let data = try await getWidgetData()
        if let scholar = data.scholars.first(where: { $0.id == id }) {
            await storage.writeValue(scholar.name, forKey: UnifiedDataStorage.Keys.selectedScholarName)
        }
        
        // 清除缓存以强制重新加载
        await clearCache()
        
        // 通知Widget更新
        await notifyWidgetUpdate()
        
        print("✅ [WidgetDataService] 更新选中学者: \(id)")
    }
    
    /// 记录刷新动作（用于Widget动画）
    public func recordRefreshAction() async {
        let now = Date()
        
        // 记录刷新时间戳
        await storage.writeValue(now, forKey: UnifiedDataStorage.Keys.lastRefreshTime)
        await storage.writeValue(now, forKey: "RefreshTriggerTime")
        await storage.writeValue(true, forKey: "RefreshTriggered")
        print("🧪 [WidgetDataService] 记录刷新动作: LastRefreshTime=\(now)")
        
        // 清除缓存
        await clearCache()
        
        // 通知Widget更新
        await notifyWidgetUpdate()
        
        print("✅ [WidgetDataService] 记录刷新动作")
    }
    
    /// 记录学者切换动作（用于Widget动画）
    public func recordScholarSwitchAction() async {
        let now = Date()
        
        // 记录切换时间戳
        await storage.writeValue(now, forKey: "LastScholarSwitchTime")
        await storage.writeValue(true, forKey: "ScholarSwitched")
        
        // 通知Widget更新
        await notifyWidgetUpdate()
        
        print("✅ [WidgetDataService] 记录学者切换动作")
    }
    
    // MARK: - 数据同步
    
    /// 从主应用同步数据到Widget
    public func syncFromMainApp() async throws {
        print("🔄 [WidgetDataService] 从主应用同步数据...")
        
        // 清除缓存以强制重新加载
        await clearCache()
        
        // 重新加载数据
        let _ = try await getWidgetData()
        
        // 通知Widget更新
        await notifyWidgetUpdate()
        
        print("✅ [WidgetDataService] 从主应用同步完成")
    }
    
    /// 检查数据是否需要更新
    public func needsDataUpdate() async -> Bool {
        // 检查App Group中的数据是否比缓存新
        if let lastUpdateTime = await storage.readValue(forKey: UnifiedDataStorage.Keys.lastRefreshTime) as? Date,
           let cachedData = cachedWidgetData,
           let cacheUpdateTime = cachedData.lastUpdateTime {
            return lastUpdateTime > cacheUpdateTime
        }
        
        // 如果没有缓存或无法比较，则需要更新
        return cachedWidgetData == nil
    }
    
    // MARK: - Widget通知
    
    /// 通知Widget更新
    private func notifyWidgetUpdate() async {
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        // 发布数据更新通知
        if let data = try? await getWidgetData() {
            await MainActor.run {
                print("🧪 [WidgetDataService] notifyWidgetUpdate 触发，lastUpdateTime=\(data.lastUpdateTime?.description ?? "nil")")
                self.dataUpdateSubject.send(data)
            }
        }
    }
    
    // MARK: - 缓存管理
    
    private func isCacheValid() -> Bool {
        return Date().timeIntervalSince(lastCacheTime) < cacheValidityDuration
    }
    
    private func clearCache() async {
        cachedWidgetData = nil
        lastCacheTime = .distantPast
    }
    
    // MARK: - 发布者
    
    public var dataUpdatePublisher: AnyPublisher<WidgetData, Never> {
        dataUpdateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 错误处理和恢复
    
    /// 尝试恢复损坏的数据
    public func recoverCorruptedData() async throws {
        print("🔧 [WidgetDataService] 尝试恢复损坏的数据...")
        
        // 清除所有缓存
        await clearCache()
        
        // 尝试重新加载数据
        do {
            let data = try await loadWidgetDataFromStorage()
            cachedWidgetData = data
            lastCacheTime = Date()
            
            print("✅ [WidgetDataService] 数据恢复成功")
        } catch {
            print("❌ [WidgetDataService] 数据恢复失败: \(error)")
            
            // 如果无法恢复，创建空的数据结构
            let emptyData = WidgetData(
                scholars: [],
                selectedScholarId: nil,
                totalCitations: 0,
                lastUpdateTime: Date()
            )
            
            cachedWidgetData = emptyData
            lastCacheTime = Date()
            
            throw DataRepositoryError.storageError(error)
        }
    }
    
    // MARK: - 调试工具
    
    /// 获取调试信息
    public func getDebugInfo() async -> WidgetDebugInfo {
        let hasCache = cachedWidgetData != nil
        let cacheAge = Date().timeIntervalSince(lastCacheTime)
        let isAppGroupAvailable = storage.isAppGroupAvailable
        
        let (standardKeys, appGroupKeys) = await storage.getAllKeys()
        
        return WidgetDebugInfo(
            hasCache: hasCache,
            cacheAge: cacheAge,
            isAppGroupAvailable: isAppGroupAvailable,
            standardKeysCount: standardKeys.count,
            appGroupKeysCount: appGroupKeys.count,
            lastCacheTime: lastCacheTime
        )
    }
}

// MARK: - 调试信息结构
public struct WidgetDebugInfo {
    public let hasCache: Bool
    public let cacheAge: TimeInterval
    public let isAppGroupAvailable: Bool
    public let standardKeysCount: Int
    public let appGroupKeysCount: Int
    public let lastCacheTime: Date
    
    public var description: String {
        return """
        Widget数据服务调试信息:
        - 有缓存: \(hasCache)
        - 缓存年龄: \(String(format: "%.1f", cacheAge))秒
        - App Group可用: \(isAppGroupAvailable)
        - 标准存储键数量: \(standardKeysCount)
        - App Group键数量: \(appGroupKeysCount)
        - 最后缓存时间: \(lastCacheTime)
        """
    }
}

// MARK: - 便捷扩展
public extension WidgetDataService {
    
    /// 切换到下一个学者
    func switchToNextScholar() async throws {
        let data = try await getWidgetData()
        
        guard !data.scholars.isEmpty else {
            throw DataRepositoryError.invalidData("没有可用的学者")
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
        
        print("✅ [WidgetDataService] 切换到下一个学者: \(nextScholar.name)")
    }
    
    /// 切换到上一个学者
    func switchToPreviousScholar() async throws {
        let data = try await getWidgetData()
        
        guard !data.scholars.isEmpty else {
            throw DataRepositoryError.invalidData("没有可用的学者")
        }
        
        let currentIndex: Int
        if let selectedId = data.selectedScholarId,
           let index = data.scholars.firstIndex(where: { $0.id == selectedId }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        
        let previousIndex = currentIndex > 0 ? currentIndex - 1 : data.scholars.count - 1
        let previousScholar = data.scholars[previousIndex]
        
        try await updateSelectedScholar(id: previousScholar.id)
        await recordScholarSwitchAction()
        
        print("✅ [WidgetDataService] 切换到上一个学者: \(previousScholar.name)")
    }
}
