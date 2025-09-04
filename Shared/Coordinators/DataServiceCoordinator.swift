import Foundation
import Combine

// MARK: - 数据服务协调器
/// 负责协调和管理所有数据相关的服务
/// 确保数据的一致性和服务间的正确协作
public class DataServiceCoordinator: ObservableObject {
    
    // MARK: - Properties
    
    public static let shared = DataServiceCoordinator()
    
    // 核心服务
    public let repository: DataRepository
    private let migrationService: DataMigrationService
    
    // 发布的状态
    @Published public var isInitialized = false
    @Published public var migrationStatus: MigrationStatus = .notStarted
    @Published public var lastSyncTime: Date?
    
    // 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        self.repository = DataRepository.shared
        self.migrationService = DataMigrationService(repository: repository)
        
        setupObservers()
    }
    
    // MARK: - 初始化流程
    
    /// 初始化数据服务
    public func initialize() async throws {
        print("🚀 [DataServiceCoordinator] 开始初始化数据服务...")
        
        // 1. 检查是否需要迁移
        if await migrationService.needsMigration() {
            await updateMigrationStatus(.inProgress)
            
            do {
                try await migrationService.performMigration()
                await updateMigrationStatus(.completed)
                print("✅ [DataServiceCoordinator] 数据迁移完成")
            } catch {
                await updateMigrationStatus(.failed(error.localizedDescription))
                print("❌ [DataServiceCoordinator] 数据迁移失败: \(error)")
                throw error
            }
        } else {
            await updateMigrationStatus(.notNeeded)
        }
        
        // 2. 验证数据完整性
        try await validateAndRepairData()
        
        // 3. 执行初始同步
        try await performInitialSync()
        
        // 4. 标记初始化完成
        await MainActor.run {
            self.isInitialized = true
        }
        
        print("✅ [DataServiceCoordinator] 数据服务初始化完成")
    }
    
    // MARK: - 数据验证和修复
    
    private func validateAndRepairData() async throws {
        print("🔍 [DataServiceCoordinator] 验证数据完整性...")
        
        let validationResult = try await repository.validateDataIntegrity()
        
        if !validationResult.isValid {
            print("⚠️ [DataServiceCoordinator] 发现数据完整性问题: \(validationResult.issues)")
            
            if !validationResult.fixableIssues.isEmpty {
                try await repository.repairDataIntegrity()
                print("✅ [DataServiceCoordinator] 数据完整性问题已修复")
            }
        } else {
            print("✅ [DataServiceCoordinator] 数据完整性验证通过")
        }
    }
    
    // MARK: - 数据同步
    
    private func performInitialSync() async throws {
        print("🔄 [DataServiceCoordinator] 执行初始数据同步...")
        
        do {
            try await repository.syncToAppGroup()
            
            await MainActor.run {
                self.lastSyncTime = Date()
            }
            
            print("✅ [DataServiceCoordinator] 初始同步完成")
        } catch {
            print("❌ [DataServiceCoordinator] 初始同步失败: \(error)")
            // 不抛出错误，同步失败不应该阻止应用启动
        }
    }
    
    /// 手动触发同步
    public func triggerSync() async {
        do {
            try await repository.syncToAppGroup()
            
            await MainActor.run {
                self.lastSyncTime = Date()
            }
            
            print("✅ [DataServiceCoordinator] 手动同步完成")
        } catch {
            print("❌ [DataServiceCoordinator] 手动同步失败: \(error)")
        }
    }
    
    // MARK: - 观察者设置
    
    private func setupObservers() {
        // 观察同步状态
        repository.syncStatusPublisher
            .sink { [weak self] status in
                if case .success(let date) = status {
                    Task { @MainActor in
                        self?.lastSyncTime = date
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 状态更新
    
    @MainActor
    private func updateMigrationStatus(_ status: MigrationStatus) {
        self.migrationStatus = status
    }
    
    // MARK: - 便捷访问方法
    
    /// 获取学者数据
    public func getScholars() async throws -> [Scholar] {
        try await repository.fetchScholars()
    }
    
    /// 保存学者
    public func saveScholar(_ scholar: Scholar) async throws {
        try await repository.saveScholar(scholar)
        await triggerSync() // 自动同步
    }
    
    /// 删除学者
    public func deleteScholar(id: String) async throws {
        try await repository.deleteScholar(id: id)
        await triggerSync() // 自动同步
    }
    
    /// 获取Widget数据
    public func getWidgetData() async throws -> WidgetData {
        try await repository.fetchWidgetData()
    }
    
    /// 更新Widget数据
    public func updateWidgetData(_ data: WidgetData) async throws {
        try await repository.updateWidgetData(data)
    }
    
    /// 获取引用历史
    public func getCitationHistory(for scholarId: String, from startDate: Date? = nil, to endDate: Date? = nil) async throws -> [CitationHistory] {
        try await repository.fetchCitationHistory(for: scholarId, from: startDate, to: endDate)
    }
    
    /// 保存引用历史
    public func saveCitationHistory(_ history: CitationHistory) async throws {
        try await repository.saveCitationHistory(history)
    }
    
    /// 获取数据统计
    public func getDataStatistics() async throws -> DataStatistics {
        try await repository.fetchDataStatistics()
    }
    
    /// 获取引用增长数据
    public func getCitationGrowth(for scholarId: String, days: Int) async throws -> CitationGrowth? {
        try await repository.fetchCitationGrowth(for: scholarId, days: days)
    }
    
    // MARK: - 发布者访问
    
    /// 学者数据发布者
    public var scholarsPublisher: AnyPublisher<[Scholar], Never> {
        repository.scholarsPublisher
    }
    
    /// Widget数据发布者
    public var widgetDataPublisher: AnyPublisher<WidgetData, Never> {
        repository.widgetDataPublisher
    }
    
    /// 同步状态发布者
    public var syncStatusPublisher: AnyPublisher<DataSyncStatus, Never> {
        repository.syncStatusPublisher
    }
    
    // MARK: - 清理
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - 迁移状态
public enum MigrationStatus: Equatable {
    case notStarted
    case inProgress
    case completed
    case notNeeded
    case failed(String)
    
    public var description: String {
        switch self {
        case .notStarted:
            return "未开始"
        case .inProgress:
            return "进行中"
        case .completed:
            return "已完成"
        case .notNeeded:
            return "无需迁移"
        case .failed(let error):
            return "失败: \(error)"
        }
    }
}

// MARK: - 便捷扩展
public extension DataServiceCoordinator {
    
    /// 检查初始化状态
    var isReady: Bool {
        return isInitialized && migrationStatus != .inProgress
    }
    
    /// 获取当前选中的学者
    func getCurrentSelectedScholar() async throws -> Scholar? {
        guard let id = try await repository.getCurrentSelectedScholarId() else {
            return nil
        }
        return try await repository.fetchScholar(id: id)
    }
    
    /// 设置当前选中的学者
    func setCurrentSelectedScholar(id: String) async throws {
        try await repository.setCurrentSelectedScholar(id: id)
        await triggerSync()
    }
    
    /// 强制重新初始化
    func reinitialize() async throws {
        await MainActor.run {
            self.isInitialized = false
            self.migrationStatus = .notStarted
        }
        
        try await initialize()
    }
}
