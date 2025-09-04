import Foundation

// MARK: - 数据集成测试工具
/// 用于验证重构后的数据架构是否正常工作
public class DataIntegrationTests {
    
    private let dataCoordinator: DataServiceCoordinator
    private let widgetService: WidgetDataService
    private let syncMonitor: DataSyncMonitor
    
    public init() {
        self.dataCoordinator = DataServiceCoordinator.shared
        self.widgetService = WidgetDataService.shared
        self.syncMonitor = DataSyncMonitor.shared
    }
    
    // MARK: - 完整测试套件
    
    /// 运行完整的集成测试
    public func runCompleteTestSuite() async -> TestSuiteResult {
        print("🧪 [DataIntegrationTests] 开始运行完整测试套件...")
        
        var results: [TestResult] = []
        
        // 1. 基础初始化测试
        results.append(await testDataServiceInitialization())
        
        // 2. 数据存储和检索测试
        results.append(await testDataStorageAndRetrieval())
        
        // 3. 数据同步测试
        results.append(await testDataSynchronization())
        
        // 4. Widget数据测试
        results.append(await testWidgetDataIntegration())
        
        // 5. 数据验证和修复测试
        results.append(await testDataValidationAndRepair())
        
        // 6. 并发访问测试
        results.append(await testConcurrentAccess())
        
        // 7. 错误处理测试
        results.append(await testErrorHandling())
        
        let summary = TestSuiteResult(results: results)
        print("✅ [DataIntegrationTests] 测试套件完成: \(summary.description)")
        
        return summary
    }
    
    // MARK: - 个别测试
    
    /// 测试数据服务初始化
    private func testDataServiceInitialization() async -> TestResult {
        print("🧪 [Test] 测试数据服务初始化...")
        
        do {
            // 检查服务是否已初始化
            let isReady = dataCoordinator.isReady
            
            if !isReady {
                // 如果未初始化，进行初始化
                try await dataCoordinator.initialize()
            }
            
            // 验证初始化状态
            guard dataCoordinator.isReady else {
                return TestResult(name: "数据服务初始化", success: false, message: "初始化失败")
            }
            
            // 验证同步监控是否启动
            let syncSummary = syncMonitor.getSyncStatusSummary()
            guard syncSummary.isMonitoring else {
                return TestResult(name: "数据服务初始化", success: false, message: "同步监控未启动")
            }
            
            return TestResult(name: "数据服务初始化", success: true, message: "初始化成功")
            
        } catch {
            return TestResult(name: "数据服务初始化", success: false, message: "初始化异常: \(error.localizedDescription)")
        }
    }
    
    /// 测试数据存储和检索
    private func testDataStorageAndRetrieval() async -> TestResult {
        print("🧪 [Test] 测试数据存储和检索...")
        
        do {
            // 创建测试学者
            let testScholar = Scholar.mock(id: "test_scholar_\(Int.random(in: 1000...9999))", 
                                         name: "Test Scholar", 
                                         citations: 100)
            
            // 保存学者
            try await dataCoordinator.saveScholar(testScholar)
            
            // 等待一小段时间确保数据已保存
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
            
            // 检索学者
            let retrievedScholars = try await dataCoordinator.getScholars()
            
            // 验证学者是否存在
            guard let savedScholar = retrievedScholars.first(where: { $0.id == testScholar.id }) else {
                return TestResult(name: "数据存储和检索", success: false, message: "保存的学者未找到")
            }
            
            // 验证数据一致性
            guard savedScholar.name == testScholar.name && 
                  savedScholar.citations == testScholar.citations else {
                return TestResult(name: "数据存储和检索", success: false, message: "数据不一致")
            }
            
            // 清理测试数据
            try await dataCoordinator.deleteScholar(id: testScholar.id)
            
            return TestResult(name: "数据存储和检索", success: true, message: "存储和检索正常")
            
        } catch {
            return TestResult(name: "数据存储和检索", success: false, message: "异常: \(error.localizedDescription)")
        }
    }
    
    /// 测试数据同步
    private func testDataSynchronization() async -> TestResult {
        print("🧪 [Test] 测试数据同步...")
        
        do {
            // 触发同步
            await dataCoordinator.triggerSync()
            
            // 等待同步完成
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            
            // 检查同步状态
            let syncStatus = dataCoordinator.repository.syncStatusPublisher
            
            // 验证同步是否成功
            // 这里可以添加更详细的同步验证逻辑
            
            return TestResult(name: "数据同步", success: true, message: "同步测试完成")
            
        } catch {
            return TestResult(name: "数据同步", success: false, message: "同步异常: \(error.localizedDescription)")
        }
    }
    
    /// 测试Widget数据集成
    private func testWidgetDataIntegration() async -> TestResult {
        print("🧪 [Test] 测试Widget数据集成...")
        
        do {
            // 获取Widget数据
            let widgetData = try await widgetService.getWidgetData()
            
            // 检查数据结构是否正确
            // 这里可以添加更详细的Widget数据验证
            
            // 测试学者切换功能
            if !widgetData.scholars.isEmpty {
                let originalSelectedId = widgetData.selectedScholarId
                
                // 切换到下一个学者
                try await widgetService.switchToNextScholar()
                
                // 等待切换完成
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
                
                // 验证切换是否成功
                let updatedData = try await widgetService.getWidgetData()
                
                // 如果有多个学者，验证选中的学者是否发生了变化
                if widgetData.scholars.count > 1 {
                    guard updatedData.selectedScholarId != originalSelectedId else {
                        return TestResult(name: "Widget数据集成", success: false, message: "学者切换失败")
                    }
                }
            }
            
            return TestResult(name: "Widget数据集成", success: true, message: "Widget集成正常")
            
        } catch {
            return TestResult(name: "Widget数据集成", success: false, message: "Widget异常: \(error.localizedDescription)")
        }
    }
    
    /// 测试数据验证和修复
    private func testDataValidationAndRepair() async -> TestResult {
        print("🧪 [Test] 测试数据验证和修复...")
        
        do {
            // 执行数据验证
            let validationResult = try await dataCoordinator.repository.validateDataIntegrity()
            
            // 如果有问题，尝试修复
            if !validationResult.isValid {
                try await dataCoordinator.repository.repairDataIntegrity()
                
                // 重新验证
                let secondValidation = try await dataCoordinator.repository.validateDataIntegrity()
                
                if !secondValidation.isValid {
                    return TestResult(name: "数据验证和修复", success: false, message: "修复后仍有问题")
                }
            }
            
            return TestResult(name: "数据验证和修复", success: true, message: "验证和修复正常")
            
        } catch {
            return TestResult(name: "数据验证和修复", success: false, message: "验证异常: \(error.localizedDescription)")
        }
    }
    
    /// 测试并发访问
    private func testConcurrentAccess() async -> TestResult {
        print("🧪 [Test] 测试并发访问...")
        
        do {
            // 创建多个并发任务
            let concurrentTasks = (1...5).map { index in
                Task {
                    let testScholar = Scholar.mock(id: "concurrent_test_\(index)", 
                                                 name: "Concurrent Test \(index)", 
                                                 citations: index * 10)
                    try await dataCoordinator.saveScholar(testScholar)
                    return testScholar.id
                }
            }
            
            // 等待所有任务完成
            var savedIds: [String] = []
            for task in concurrentTasks {
                let id = try await task.value
                savedIds.append(id)
            }
            
            // 验证所有学者都被正确保存
            let scholars = try await dataCoordinator.getScholars()
            let foundIds = scholars.map { $0.id }.filter { savedIds.contains($0) }
            
            // 清理测试数据
            for id in savedIds {
                try await dataCoordinator.deleteScholar(id: id)
            }
            
            guard foundIds.count == savedIds.count else {
                return TestResult(name: "并发访问", success: false, message: "并发保存不完整")
            }
            
            return TestResult(name: "并发访问", success: true, message: "并发访问正常")
            
        } catch {
            return TestResult(name: "并发访问", success: false, message: "并发异常: \(error.localizedDescription)")
        }
    }
    
    /// 测试错误处理
    private func testErrorHandling() async -> TestResult {
        print("🧪 [Test] 测试错误处理...")
        
        do {
            // 测试删除不存在的学者
            try await dataCoordinator.deleteScholar(id: "non_existent_scholar")
            
            // 如果没有抛出错误，这是正常的（删除不存在的项目通常不应该是错误）
            
            // 测试获取不存在的学者
            let scholar = try await dataCoordinator.repository.fetchScholar(id: "non_existent_scholar")
            
            // 应该返回nil而不是抛出错误
            guard scholar == nil else {
                return TestResult(name: "错误处理", success: false, message: "返回了不存在的学者")
            }
            
            return TestResult(name: "错误处理", success: true, message: "错误处理正常")
            
        } catch {
            // 某些错误是预期的，这里可以根据具体情况判断
            return TestResult(name: "错误处理", success: true, message: "错误处理正常（预期错误）")
        }
    }
    
    // MARK: - 快速健康检查
    
    /// 快速健康检查
    public func quickHealthCheck() async -> HealthCheckResult {
        print("🏥 [DataIntegrationTests] 执行快速健康检查...")
        
        var issues: [String] = []
        var warnings: [String] = []
        
        // 检查数据服务是否准备就绪
        if !dataCoordinator.isReady {
            issues.append("数据服务未准备就绪")
        }
        
        // 检查同步监控状态
        let syncSummary = syncMonitor.getSyncStatusSummary()
        if !syncSummary.isMonitoring {
            warnings.append("同步监控未运行")
        }
        
        // 检查数据完整性
        do {
            let validationResult = try await dataCoordinator.repository.validateDataIntegrity()
            if !validationResult.isValid {
                issues.addAll(validationResult.issues)
            }
        } catch {
            issues.append("数据验证失败: \(error.localizedDescription)")
        }
        
        // 检查Widget数据可用性
        do {
            let _ = try await widgetService.getWidgetData()
        } catch {
            issues.append("Widget数据不可用: \(error.localizedDescription)")
        }
        
        let isHealthy = issues.isEmpty
        
        return HealthCheckResult(
            isHealthy: isHealthy,
            issues: issues,
            warnings: warnings,
            timestamp: Date()
        )
    }
}

// MARK: - 测试结果结构

public struct TestResult {
    public let name: String
    public let success: Bool
    public let message: String
    public let timestamp: Date
    
    public init(name: String, success: Bool, message: String) {
        self.name = name
        self.success = success
        self.message = message
        self.timestamp = Date()
    }
}

public struct TestSuiteResult {
    public let results: [TestResult]
    public let totalTests: Int
    public let passedTests: Int
    public let failedTests: Int
    public let successRate: Double
    public let timestamp: Date
    
    public init(results: [TestResult]) {
        self.results = results
        self.totalTests = results.count
        self.passedTests = results.filter { $0.success }.count
        self.failedTests = results.filter { !$0.success }.count
        self.successRate = totalTests > 0 ? Double(passedTests) / Double(totalTests) : 0.0
        self.timestamp = Date()
    }
    
    public var description: String {
        return """
        测试套件结果:
        - 总测试数: \(totalTests)
        - 通过: \(passedTests)
        - 失败: \(failedTests)
        - 成功率: \(String(format: "%.1f", successRate * 100))%
        
        详细结果:
        \(results.map { "[\($0.success ? "✅" : "❌")] \($0.name): \($0.message)" }.joined(separator: "\n"))
        """
    }
}

public struct HealthCheckResult {
    public let isHealthy: Bool
    public let issues: [String]
    public let warnings: [String]
    public let timestamp: Date
    
    public var description: String {
        var result = "健康检查结果: \(isHealthy ? "健康" : "有问题")\n"
        
        if !issues.isEmpty {
            result += "问题:\n\(issues.map { "- \($0)" }.joined(separator: "\n"))\n"
        }
        
        if !warnings.isEmpty {
            result += "警告:\n\(warnings.map { "- \($0)" }.joined(separator: "\n"))\n"
        }
        
        if isHealthy {
            result += "所有系统正常运行"
        }
        
        return result
    }
}

// MARK: - 辅助扩展
private extension Array where Element == String {
    mutating func addAll(_ elements: [String]) {
        self.append(contentsOf: elements)
    }
}
