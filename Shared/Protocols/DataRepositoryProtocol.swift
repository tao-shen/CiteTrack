import Foundation
import Combine

// MARK: - 数据仓库协议 - 统一数据访问接口
/// 定义所有数据操作的统一接口，确保数据一致性
public protocol DataRepositoryProtocol {
    
    // MARK: - 学者数据管理
    
    /// 获取所有学者
    func fetchScholars() async throws -> [Scholar]
    
    /// 获取指定学者
    func fetchScholar(id: String) async throws -> Scholar?
    
    /// 保存学者信息
    func saveScholar(_ scholar: Scholar) async throws
    
    /// 更新学者信息
    func updateScholar(_ scholar: Scholar) async throws
    
    /// 删除学者
    func deleteScholar(id: String) async throws
    
    /// 删除所有学者
    func deleteAllScholars() async throws
    
    // MARK: - 引用历史管理
    
    /// 获取指定学者的引用历史
    func fetchCitationHistory(for scholarId: String, from startDate: Date?, to endDate: Date?) async throws -> [CitationHistory]
    
    /// 获取所有引用历史
    func fetchAllCitationHistory() async throws -> [CitationHistory]
    
    /// 保存引用历史记录
    func saveCitationHistory(_ history: CitationHistory) async throws
    
    /// 删除指定学者的历史记录
    func deleteCitationHistory(for scholarId: String) async throws
    
    /// 删除所有历史记录
    func deleteAllCitationHistory() async throws
    
    // MARK: - Widget数据管理
    
    /// 获取Widget显示数据
    func fetchWidgetData() async throws -> WidgetData
    
    /// 更新Widget数据
    func updateWidgetData(_ data: WidgetData) async throws
    
    /// 获取当前选中的学者ID
    func getCurrentSelectedScholarId() async throws -> String?
    
    /// 设置当前选中的学者
    func setCurrentSelectedScholar(id: String) async throws
    
    // MARK: - 数据统计
    
    /// 获取数据统计信息
    func fetchDataStatistics() async throws -> DataStatistics
    
    /// 获取学者的增长数据
    func fetchCitationGrowth(for scholarId: String, days: Int) async throws -> CitationGrowth?
    
    /// 获取多时间段增长数据
    func fetchMultiPeriodGrowth(for scholarId: String) async throws -> MultiPeriodGrowth?
    
    // MARK: - 数据同步与一致性
    
    /// 同步数据到App Group
    func syncToAppGroup() async throws
    
    /// 从App Group同步数据
    func syncFromAppGroup() async throws
    
    /// 验证数据完整性
    func validateDataIntegrity() async throws -> DataValidationResult
    
    /// 修复数据完整性问题
    func repairDataIntegrity() async throws
    
    // MARK: - 数据观察
    
    /// 观察学者数据变化
    var scholarsPublisher: AnyPublisher<[Scholar], Never> { get }
    
    /// 观察Widget数据变化
    var widgetDataPublisher: AnyPublisher<WidgetData, Never> { get }
    
    /// 观察数据同步状态
    var syncStatusPublisher: AnyPublisher<DataSyncStatus, Never> { get }
}

// MARK: - 支持类型定义

/// Widget显示数据
public struct WidgetData: Codable, Equatable {
    public let scholars: [WidgetScholarInfo]
    public let selectedScholarId: String?
    public let totalCitations: Int
    public let lastUpdateTime: Date?
    
    public init(scholars: [WidgetScholarInfo], selectedScholarId: String?, totalCitations: Int, lastUpdateTime: Date?) {
        self.scholars = scholars
        self.selectedScholarId = selectedScholarId
        self.totalCitations = totalCitations
        self.lastUpdateTime = lastUpdateTime
    }
}

/// 数据同步状态
public enum DataSyncStatus: Equatable {
    case idle
    case syncing
    case success(Date)
    case failure(String)
}

/// 数据验证结果
public struct DataValidationResult: Equatable {
    public let isValid: Bool
    public let issues: [String]
    public let fixableIssues: [String]
    
    public init(isValid: Bool, issues: [String], fixableIssues: [String]) {
        self.isValid = isValid
        self.issues = issues
        self.fixableIssues = fixableIssues
    }
}

/// 数据操作错误
public enum DataRepositoryError: Error, LocalizedError {
    case scholarNotFound(String)
    case invalidData(String)
    case syncFailure(String)
    case storageError(Error)
    case validationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .scholarNotFound(let id):
            return "未找到学者: \(id)"
        case .invalidData(let message):
            return "无效数据: \(message)"
        case .syncFailure(let message):
            return "同步失败: \(message)"
        case .storageError(let error):
            return "存储错误: \(error.localizedDescription)"
        case .validationError(let message):
            return "验证错误: \(message)"
        }
    }
}
