import Foundation
import Combine
import CoreFoundation
#if os(iOS)
import WidgetKit
#endif

// MARK: - 新的数据管理器
/// 重构后的数据管理器，职责更加明确，使用统一的数据访问接口
/// 主要负责业务逻辑和数据操作的协调
@MainActor
public class NewDataManager: ObservableObject {
    
    // MARK: - Properties
    
    public static let shared = NewDataManager()
    
    // 数据服务
    private let dataCoordinator: DataServiceCoordinator
    private let unifiedStorage = UnifiedDataStorage()
    private let widgetService: WidgetDataService
    private let syncMonitor: DataSyncMonitor
    
    // 发布的数据
    @Published public var scholars: [Scholar] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var lastUpdateTime: Date?
    
    // 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        self.dataCoordinator = DataServiceCoordinator.shared
        self.widgetService = WidgetDataService.shared
        self.syncMonitor = DataSyncMonitor.shared
        
        setupObservers()
        
        // 启动数据服务
        Task {
            await initializeDataServices()
        }
    }
    
    // MARK: - 初始化
    
    private func initializeDataServices() async {
        isLoading = true
        
        do {
            // 初始化数据服务协调器
            try await dataCoordinator.initialize()
            
            // 启动同步监控
            syncMonitor.startMonitoring()
            
            print("✅ [NewDataManager] 数据服务初始化完成")
        } catch {
            print("❌ [NewDataManager] 数据服务初始化失败: \(error)")
            errorMessage = "数据服务初始化失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - 观察者设置
    
    private func setupObservers() {
        // 监听来自Widget的Darwin通知，及时刷新lastUpdateTime
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, Unmanaged.passUnretained(self).toOpaque(), { (_, observer, name, _, _) in
            guard let name = name else { return }
            let n = name.rawValue as String
            if n == "com.citetrack.lastRefreshTimeUpdated" {
                Task { @MainActor in
                    let storage = UnifiedDataStorage()
                    if let t = await storage.readValue(forKey: UnifiedDataStorage.Keys.lastRefreshTime) as? Date {
                        let manager = Unmanaged<NewDataManager>.fromOpaque(observer!).takeUnretainedValue()
                        let old = manager.lastUpdateTime
                        manager.lastUpdateTime = t
                        print("🧪 [NewDataManager] 收到Darwin通知，更新 lastUpdateTime: old=\(old?.description ?? "nil") -> new=\(t)")
                    }
                }
            }
        }, "com.citetrack.lastRefreshTimeUpdated" as CFString, nil, .deliverImmediately)

        // 观察学者数据变化
        dataCoordinator.scholarsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scholars in
                self?.scholars = scholars
                self?.lastUpdateTime = Date()
            }
            .store(in: &cancellables)
        
        // 观察数据服务协调器的初始化状态
        dataCoordinator.$isInitialized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isInitialized in
                if isInitialized {
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)

        // 观察 Widget 数据（含统一的 lastUpdateTime），用于从小组件更新时同步到主应用
        dataCoordinator.widgetDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] widgetData in
                // 仅更新显示用的最后刷新时间，避免打断其他流程
                if let ts = widgetData.lastUpdateTime {
                    let old = self?.lastUpdateTime
                    self?.lastUpdateTime = ts
                    print("🧪 [NewDataManager] 从widgetDataPublisher接收 lastUpdateTime: old=\(old?.description ?? "nil") -> new=\(ts)")
                }
            }
            .store(in: &cancellables)

        // 轮询统一存储的 LastRefreshTime，确保即使仅小组件写入也能反映到主应用
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    if let t = await self.unifiedStorage.readValue(forKey: UnifiedDataStorage.Keys.lastRefreshTime) as? Date {
                        if self.lastUpdateTime == nil || (self.lastUpdateTime ?? .distantPast) != t {
                            let old = self.lastUpdateTime
                            self.lastUpdateTime = t
                            print("🧪 [NewDataManager] 轮询捕获 LastRefreshTime 变更: old=\(old?.description ?? "nil") -> new=\(t)")
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 学者管理
    
    /// 添加学者
    public func addScholar(_ scholar: Scholar) async {
        do {
            try await dataCoordinator.saveScholar(scholar)
            print("✅ [NewDataManager] 添加学者成功: \(scholar.displayName)")
            clearError()
        } catch {
            handleError("添加学者失败", error: error)
        }
    }
    
    /// 更新学者信息
    public func updateScholar(_ scholar: Scholar) async {
        do {
            try await dataCoordinator.saveScholar(scholar)
            print("✅ [NewDataManager] 更新学者成功: \(scholar.displayName)")
            clearError()
        } catch {
            handleError("更新学者失败", error: error)
        }
    }
    
    /// 删除学者
    public func deleteScholar(id: String) async {
        do {
            try await dataCoordinator.deleteScholar(id: id)
            print("✅ [NewDataManager] 删除学者成功: \(id)")
            clearError()
        } catch {
            handleError("删除学者失败", error: error)
        }
    }
    
    /// 获取学者信息
    public func getScholar(id: String) -> Scholar? {
        return scholars.first { $0.id == id }
    }
    
    /// 刷新所有学者数据
    public func refreshAllScholars() async {
        isLoading = true
        
        do {
            // 这里可以添加从网络更新学者信息的逻辑
            // 目前只是重新加载数据
            let updatedScholars = try await dataCoordinator.getScholars()
            scholars = updatedScholars
            lastUpdateTime = Date()
            
            // 记录刷新动作（用于Widget动画）
            await widgetService.recordRefreshAction()
            
            print("✅ [NewDataManager] 刷新所有学者数据完成")
            clearError()
        } catch {
            handleError("刷新学者数据失败", error: error)
        }
        
        isLoading = false
    }
    
    // MARK: - 引用历史管理
    
    /// 获取学者的引用历史
    public func getCitationHistory(for scholarId: String, from startDate: Date? = nil, to endDate: Date? = nil) async -> [CitationHistory] {
        do {
            return try await dataCoordinator.getCitationHistory(for: scholarId, from: startDate, to: endDate)
        } catch {
            handleError("获取引用历史失败", error: error)
            return []
        }
    }
    
    /// 添加引用历史记录
    public func addCitationHistory(_ history: CitationHistory) async {
        do {
            try await dataCoordinator.saveCitationHistory(history)
            print("✅ [NewDataManager] 添加引用历史成功")
            clearError()
        } catch {
            handleError("添加引用历史失败", error: error)
        }
    }
    
    // MARK: - Widget相关
    
    /// 获取当前选中的学者
    public func getCurrentSelectedScholar() async -> Scholar? {
        do {
            return try await dataCoordinator.getCurrentSelectedScholar()
        } catch {
            print("❌ [NewDataManager] 获取当前选中学者失败: \(error)")
            return nil
        }
    }
    
    /// 设置当前选中的学者
    public func setCurrentSelectedScholar(id: String) async {
        do {
            try await dataCoordinator.setCurrentSelectedScholar(id: id)
            await widgetService.recordScholarSwitchAction()
            print("✅ [NewDataManager] 设置选中学者成功: \(id)")
            clearError()
        } catch {
            handleError("设置选中学者失败", error: error)
        }
    }
    
    /// 切换到下一个学者（用于Widget）
    public func switchToNextScholar() async {
        do {
            try await widgetService.switchToNextScholar()
            print("✅ [NewDataManager] 切换到下一个学者成功")
            clearError()
        } catch {
            handleError("切换学者失败", error: error)
        }
    }
    
    // MARK: - 数据统计
    
    /// 获取数据统计信息
    public func getDataStatistics() async -> DataStatistics? {
        do {
            return try await dataCoordinator.getDataStatistics()
        } catch {
            handleError("获取数据统计失败", error: error)
            return nil
        }
    }
    
    /// 获取学者的引用增长数据
    public func getCitationGrowth(for scholarId: String, days: Int) async -> CitationGrowth? {
        do {
            return try await dataCoordinator.getCitationGrowth(for: scholarId, days: days)
        } catch {
            print("❌ [NewDataManager] 获取引用增长数据失败: \(error)")
            return nil
        }
    }
    
    // MARK: - 数据同步
    
    /// 手动触发数据同步
    public func triggerSync() async {
        await dataCoordinator.triggerSync()
    }
    
    /// 强制同步数据
    public func forceSync() async {
        await syncMonitor.forceSyncNow()
    }
    
    /// 获取同步状态
    public func getSyncStatus() -> DataSyncStatus {
        return syncMonitor.syncStatus
    }
    
    // MARK: - 数据验证和修复
    
    /// 验证数据完整性
    public func validateData() async -> DataValidationResult? {
        do {
            return try await dataCoordinator.repository.validateDataIntegrity()
        } catch {
            handleError("数据验证失败", error: error)
            return nil
        }
    }
    
    /// 修复数据完整性问题
    public func repairData() async {
        do {
            try await dataCoordinator.repository.repairDataIntegrity()
            print("✅ [NewDataManager] 数据修复完成")
            clearError()
        } catch {
            handleError("数据修复失败", error: error)
        }
    }
    
    // MARK: - 错误处理
    
    private func handleError(_ message: String, error: Error) {
        let fullMessage = "\(message): \(error.localizedDescription)"
        print("❌ [NewDataManager] \(fullMessage)")
        errorMessage = fullMessage
    }
    
    private func clearError() {
        errorMessage = nil
    }
    
    // MARK: - 便捷方法
    
    /// 检查数据服务是否准备就绪
    public var isReady: Bool {
        return dataCoordinator.isReady && !isLoading
    }
    
    /// 获取学者总数
    public var scholarCount: Int {
        return scholars.count
    }
    
    /// 获取总引用数
    public var totalCitations: Int {
        return scholars.compactMap { $0.citations }.reduce(0, +)
    }
    
    /// 检查是否有错误
    public var hasError: Bool {
        return errorMessage != nil
    }
    
    // MARK: - 清理
    
    deinit {
        cancellables.removeAll()
        syncMonitor.stopMonitoring()
    }
}

// MARK: - 便捷扩展
public extension NewDataManager {
    
    /// 批量操作：添加多个学者
    func addScholars(_ scholars: [Scholar]) async {
        for scholar in scholars {
            await addScholar(scholar)
        }
    }
    
    /// 批量操作：删除多个学者
    func deleteScholars(ids: [String]) async {
        for id in ids {
            await deleteScholar(id: id)
        }
    }
    
    /// 搜索学者
    func searchScholars(by query: String) -> [Scholar] {
        guard !query.isEmpty else { return scholars }
        
        return scholars.filter { scholar in
            scholar.name.localizedCaseInsensitiveContains(query) ||
            scholar.id.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// 按引用数排序学者
    func scholarsSortedByCitations(ascending: Bool = false) -> [Scholar] {
        return scholars.sorted { scholar1, scholar2 in
            let citations1 = scholar1.citations ?? 0
            let citations2 = scholar2.citations ?? 0
            return ascending ? citations1 < citations2 : citations1 > citations2
        }
    }
    
    /// 获取最近更新的学者
    func recentlyUpdatedScholars(limit: Int = 5) -> [Scholar] {
        return scholars
            .filter { $0.lastUpdated != nil }
            .sorted { ($0.lastUpdated ?? .distantPast) > ($1.lastUpdated ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }
}
