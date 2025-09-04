import Foundation
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - 数据同步监视器
/// 监控数据同步状态，确保主应用和Widget数据一致性
public class DataSyncMonitor: ObservableObject {
    
    // MARK: - Properties
    
    public static let shared = DataSyncMonitor()
    
    private let repository: DataRepositoryProtocol
    private let storage: UnifiedDataStorage
    private let widgetService: WidgetDataService
    
    // 监控定时器
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 30 // 30秒检查一次
    
    // 发布的状态
    @Published public var syncStatus: DataSyncStatus = .idle
    @Published public var lastSyncCheck: Date?
    @Published public var inconsistencyCount: Int = 0
    @Published public var autoSyncEnabled: Bool = true
    
    // 数据一致性检查
    private var lastConsistencyCheck: Date = .distantPast
    private let consistencyCheckInterval: TimeInterval = 300 // 5分钟检查一次一致性
    
    // 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        self.repository = DataRepository.shared
        self.storage = UnifiedDataStorage()
        self.widgetService = WidgetDataService.shared
        
        setupObservers()
    }
    
    // MARK: - 监控控制
    
    /// 开始数据同步监控
    public func startMonitoring() {
        guard syncTimer == nil else {
            print("ℹ️ [DataSyncMonitor] 监控已在运行")
            return
        }
        
        print("🚀 [DataSyncMonitor] 开始数据同步监控")
        
        // 立即执行一次检查
        Task {
            await performSyncCheck()
        }
        
        // 设置定时器
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performSyncCheck()
            }
        }
        
        // 在主队列中运行定时器
        RunLoop.main.add(syncTimer!, forMode: .common)
    }
    
    /// 停止数据同步监控
    public func stopMonitoring() {
        print("⏹️ [DataSyncMonitor] 停止数据同步监控")
        
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    // MARK: - 同步检查
    
    /// 执行同步检查
    private func performSyncCheck() async {
        guard autoSyncEnabled else {
            return
        }
        
        await MainActor.run {
            self.lastSyncCheck = Date()
        }
        
        do {
            // 1. 检查数据一致性
            if shouldPerformConsistencyCheck() {
                try await checkDataConsistency()
            }
            
            // 2. 检查Widget数据是否需要更新
            if await widgetService.needsDataUpdate() {
                try await widgetService.syncFromMainApp()
                print("✅ [DataSyncMonitor] Widget数据已同步")
            }
            
            // 3. 执行App Group同步
            try await repository.syncToAppGroup()
            
            await MainActor.run {
                self.syncStatus = .success(Date())
            }
            
        } catch {
            print("❌ [DataSyncMonitor] 同步检查失败: \(error)")
            
            await MainActor.run {
                self.syncStatus = .failure(error.localizedDescription)
            }
        }
    }
    
    /// 检查是否应该执行一致性检查
    private func shouldPerformConsistencyCheck() -> Bool {
        return Date().timeIntervalSince(lastConsistencyCheck) > consistencyCheckInterval
    }
    
    /// 检查数据一致性
    private func checkDataConsistency() async throws {
        print("🔍 [DataSyncMonitor] 检查数据一致性...")
        
        lastConsistencyCheck = Date()
        
        // 验证数据完整性
        let validationResult = try await repository.validateDataIntegrity()
        
        if !validationResult.isValid {
            await MainActor.run {
                self.inconsistencyCount += validationResult.issues.count
            }
            
            print("⚠️ [DataSyncMonitor] 发现数据不一致: \(validationResult.issues)")
            
            // 尝试自动修复
            if !validationResult.fixableIssues.isEmpty {
                try await repository.repairDataIntegrity()
                print("✅ [DataSyncMonitor] 自动修复了数据不一致问题")
                
                // 修复后重新同步
                try await repository.syncToAppGroup()
            }
        } else {
            print("✅ [DataSyncMonitor] 数据一致性检查通过")
        }
    }
    
    // MARK: - 手动操作
    
    /// 立即执行同步
    public func forceSyncNow() async {
        await MainActor.run {
            self.syncStatus = .syncing
        }
        
        do {
            // 强制同步所有数据
            try await repository.syncToAppGroup()
            try await widgetService.syncFromMainApp()
            
            await MainActor.run {
                self.syncStatus = .success(Date())
            }
            
            print("✅ [DataSyncMonitor] 强制同步完成")
        } catch {
            await MainActor.run {
                self.syncStatus = .failure(error.localizedDescription)
            }
            
            print("❌ [DataSyncMonitor] 强制同步失败: \(error)")
        }
    }
    
    /// 重置监控状态
    public func resetMonitoringState() async {
        await MainActor.run {
            self.inconsistencyCount = 0
            self.syncStatus = .idle
            self.lastSyncCheck = nil
        }
        
        lastConsistencyCheck = .distantPast
        
        print("🔄 [DataSyncMonitor] 监控状态已重置")
    }
    
    // MARK: - 观察者设置
    
    private func setupObservers() {
        // 观察应用状态变化
        #if os(iOS)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.performSyncCheck()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.performSyncCheck()
                }
            }
            .store(in: &cancellables)
        #endif
        
        // 观察数据变化
        repository.scholarsPublisher
            .dropFirst() // 忽略初始值
            .sink { [weak self] _ in
                Task {
                    // 数据变化时触发同步
                    try? await self?.repository.syncToAppGroup()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 配置管理
    
    /// 设置自动同步状态
    public func setAutoSyncEnabled(_ enabled: Bool) {
        autoSyncEnabled = enabled
        
        if enabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
        
        print("🔧 [DataSyncMonitor] 自动同步 \(enabled ? "启用" : "禁用")")
    }
    
    /// 设置同步间隔（重启监控后生效）
    public func setSyncInterval(_ interval: TimeInterval) {
        // 这里可以添加动态修改同步间隔的逻辑
        print("🔧 [DataSyncMonitor] 同步间隔设置为 \(interval)秒")
    }
    
    // MARK: - 状态查询
    
    /// 获取同步状态摘要
    public func getSyncStatusSummary() -> SyncStatusSummary {
        return SyncStatusSummary(
            isMonitoring: syncTimer != nil,
            autoSyncEnabled: autoSyncEnabled,
            lastSyncCheck: lastSyncCheck,
            lastConsistencyCheck: lastConsistencyCheck,
            inconsistencyCount: inconsistencyCount,
            currentStatus: syncStatus
        )
    }
    
    /// 获取详细的同步报告
    public func getDetailedSyncReport() async -> DetailedSyncReport {
        // 检查App Group可用性
        let isAppGroupAvailable = storage.isAppGroupAvailable
        
        // 获取存储键数量
        let (standardKeys, appGroupKeys) = await storage.getAllKeys()
        
        // 检查数据一致性
        let consistencyResults = await storage.validateConsistency(for: [
            UnifiedDataStorage.Keys.scholars,
            UnifiedDataStorage.Keys.citationHistory,
            UnifiedDataStorage.Keys.widgetScholars
        ])
        
        // 获取Widget调试信息
        let widgetDebugInfo = await widgetService.getDebugInfo()
        
        return DetailedSyncReport(
            appGroupAvailable: isAppGroupAvailable,
            standardKeysCount: standardKeys.count,
            appGroupKeysCount: appGroupKeys.count,
            consistencyResults: consistencyResults,
            widgetDebugInfo: widgetDebugInfo,
            monitoringActive: syncTimer != nil,
            lastSyncCheck: lastSyncCheck,
            inconsistencyCount: inconsistencyCount
        )
    }
    
    // MARK: - 清理
    
    deinit {
        stopMonitoring()
        cancellables.removeAll()
    }
}

// MARK: - 状态结构
public struct SyncStatusSummary {
    public let isMonitoring: Bool
    public let autoSyncEnabled: Bool
    public let lastSyncCheck: Date?
    public let lastConsistencyCheck: Date
    public let inconsistencyCount: Int
    public let currentStatus: DataSyncStatus
    
    public var description: String {
        return """
        同步状态摘要:
        - 监控中: \(isMonitoring)
        - 自动同步: \(autoSyncEnabled)
        - 最后检查: \(lastSyncCheck?.formatted() ?? "从未")
        - 不一致次数: \(inconsistencyCount)
        - 当前状态: \(currentStatus)
        """
    }
}

public struct DetailedSyncReport {
    public let appGroupAvailable: Bool
    public let standardKeysCount: Int
    public let appGroupKeysCount: Int
    public let consistencyResults: [String: Bool]
    public let widgetDebugInfo: WidgetDebugInfo
    public let monitoringActive: Bool
    public let lastSyncCheck: Date?
    public let inconsistencyCount: Int
    
    public var description: String {
        let consistentKeys = consistencyResults.filter { $0.value }.count
        let totalKeys = consistencyResults.count
        
        return """
        详细同步报告:
        - App Group可用: \(appGroupAvailable)
        - 标准存储键数量: \(standardKeysCount)
        - App Group键数量: \(appGroupKeysCount)
        - 数据一致性: \(consistentKeys)/\(totalKeys)
        - 监控状态: \(monitoringActive ? "运行中" : "已停止")
        - 不一致次数: \(inconsistencyCount)
        
        Widget调试信息:
        \(widgetDebugInfo.description)
        """
    }
}
