import Foundation

// MARK: - 数据迁移服务
/// 负责将现有的分散数据迁移到统一的数据管理系统
public class DataMigrationService {
    
    private let repository: DataRepository
    private let storage: UnifiedDataStorage
    
    public init(repository: DataRepository = DataRepository.shared) {
        self.repository = repository
        self.storage = UnifiedDataStorage()
    }
    
    // MARK: - 主迁移方法
    
    /// 执行完整的数据迁移
    public func performMigration() async throws {
        print("🔄 [DataMigration] 开始数据迁移...")
        
        // 1. 迁移学者数据
        try await migrateScholarsData()
        
        // 2. 迁移引用历史数据
        try await migrateCitationHistoryData()
        
        // 3. 迁移Widget相关数据
        try await migrateWidgetData()
        
        // 4. 迁移设置数据
        try await migrateSettingsData()
        
        // 5. 验证迁移结果
        try await validateMigration()
        
        // 6. 清理旧数据（可选）
        await cleanupOldData()
        
        print("✅ [DataMigration] 数据迁移完成")
    }
    
    // MARK: - 学者数据迁移
    
    private func migrateScholarsData() async throws {
        print("🔄 [DataMigration] 迁移学者数据...")
        
        // 从原有的DataManager读取数据
        let legacyScholars = await readLegacyScholars()
        
        if !legacyScholars.isEmpty {
            // 保存到新的统一存储
            try await storage.writeData(legacyScholars, forKey: UnifiedDataStorage.Keys.scholars)
            print("✅ [DataMigration] 迁移了\(legacyScholars.count)个学者")
        } else {
            print("ℹ️ [DataMigration] 没有找到需要迁移的学者数据")
        }
    }
    
    private func readLegacyScholars() async -> [Scholar] {
        // 尝试从标准UserDefaults读取
        if let data = UserDefaults.standard.data(forKey: "ScholarsList"),
           let scholars = try? JSONDecoder().decode([Scholar].self, from: data) {
            return scholars
        }
        
        // 尝试从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let data = appGroupDefaults.data(forKey: "ScholarsList"),
           let scholars = try? JSONDecoder().decode([Scholar].self, from: data) {
            return scholars
        }
        
        return []
    }
    
    // MARK: - 引用历史迁移
    
    private func migrateCitationHistoryData() async throws {
        print("🔄 [DataMigration] 迁移引用历史数据...")
        
        let legacyHistory = await readLegacyCitationHistory()
        
        if !legacyHistory.isEmpty {
            try await storage.writeData(legacyHistory, forKey: UnifiedDataStorage.Keys.citationHistory)
            print("✅ [DataMigration] 迁移了\(legacyHistory.count)条引用历史")
        } else {
            print("ℹ️ [DataMigration] 没有找到需要迁移的引用历史数据")
        }
    }
    
    private func readLegacyCitationHistory() async -> [CitationHistory] {
        // 尝试从标准UserDefaults读取
        if let data = UserDefaults.standard.data(forKey: "CitationHistoryData"),
           let history = try? JSONDecoder().decode([CitationHistory].self, from: data) {
            return history
        }
        
        // 尝试从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let data = appGroupDefaults.data(forKey: "CitationHistoryData"),
           let history = try? JSONDecoder().decode([CitationHistory].self, from: data) {
            return history
        }
        
        return []
    }
    
    // MARK: - Widget数据迁移
    
    private func migrateWidgetData() async throws {
        print("🔄 [DataMigration] 迁移Widget数据...")
        
        // 迁移选中的学者ID
        await migrateSelectedScholarId()
        
        // 迁移Widget学者数据
        await migrateWidgetScholars()
        
        // 迁移刷新时间
        await migrateRefreshTimes()
    }
    
    private func migrateSelectedScholarId() async {
        var selectedId: String?
        
        // 优先从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            selectedId = appGroupDefaults.string(forKey: "SelectedWidgetScholarId")
        }
        
        // 如果App Group没有，从标准UserDefaults读取
        if selectedId == nil {
            selectedId = UserDefaults.standard.string(forKey: "SelectedWidgetScholarId")
        }
        
        if let id = selectedId {
            await storage.writeValue(id, forKey: UnifiedDataStorage.Keys.selectedScholarId)
            print("✅ [DataMigration] 迁移选中学者ID: \(id)")
        }
    }
    
    private func migrateWidgetScholars() async {
        var widgetScholars: [WidgetScholarInfo]?
        
        // 尝试从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let data = appGroupDefaults.data(forKey: "WidgetScholars"),
           let scholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            widgetScholars = scholars
        }
        
        // 如果App Group没有，从标准UserDefaults读取
        if widgetScholars == nil,
           let data = UserDefaults.standard.data(forKey: "WidgetScholars"),
           let scholars = try? JSONDecoder().decode([WidgetScholarInfo].self, from: data) {
            widgetScholars = scholars
        }
        
        if let scholars = widgetScholars {
            try? await storage.writeData(scholars, forKey: UnifiedDataStorage.Keys.widgetScholars)
            print("✅ [DataMigration] 迁移Widget学者数据: \(scholars.count)个")
        }
    }
    
    private func migrateRefreshTimes() async {
        var lastRefreshTime: Date?
        
        // 优先从App Group读取
        if let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            lastRefreshTime = appGroupDefaults.object(forKey: "LastRefreshTime") as? Date
        }
        
        // 如果App Group没有，从标准UserDefaults读取
        if lastRefreshTime == nil {
            lastRefreshTime = UserDefaults.standard.object(forKey: "LastRefreshTime") as? Date
        }
        
        if let time = lastRefreshTime {
            await storage.writeValue(time, forKey: UnifiedDataStorage.Keys.lastRefreshTime)
            print("✅ [DataMigration] 迁移最后刷新时间: \(time)")
        }
    }
    
    // MARK: - 设置数据迁移
    
    private func migrateSettingsData() async throws {
        print("🔄 [DataMigration] 迁移设置数据...")
        
        // 这里可以根据需要迁移其他设置数据
        // 例如主题设置、语言设置等
        
        // 迁移主题设置
        if let theme = UserDefaults.standard.object(forKey: "AppTheme") {
            await storage.writeValue(theme, forKey: "AppTheme")
        }
        
        // 迁移语言设置
        if let language = UserDefaults.standard.object(forKey: "AppLanguage") {
            await storage.writeValue(language, forKey: "AppLanguage")
        }
        
        print("✅ [DataMigration] 设置数据迁移完成")
    }
    
    // MARK: - 迁移验证
    
    private func validateMigration() async throws {
        print("🔍 [DataMigration] 验证迁移结果...")
        
        // 验证学者数据
        let scholars = try await storage.readData([Scholar].self, forKey: UnifiedDataStorage.Keys.scholars) ?? []
        print("✅ [DataMigration] 学者数据验证: \(scholars.count)个")
        
        // 验证引用历史
        let history = try await storage.readData([CitationHistory].self, forKey: UnifiedDataStorage.Keys.citationHistory) ?? []
        print("✅ [DataMigration] 引用历史验证: \(history.count)条")
        
        // 验证Widget数据
        let selectedId = await storage.readValue(forKey: UnifiedDataStorage.Keys.selectedScholarId) as? String
        print("✅ [DataMigration] 选中学者验证: \(selectedId ?? "无")")
        
        // 验证数据完整性
        let validationResult = try await repository.validateDataIntegrity()
        if !validationResult.isValid {
            print("⚠️ [DataMigration] 发现数据完整性问题: \(validationResult.issues)")
            if !validationResult.fixableIssues.isEmpty {
                try await repository.repairDataIntegrity()
                print("✅ [DataMigration] 数据完整性问题已修复")
            }
        }
        
        print("✅ [DataMigration] 迁移验证完成")
    }
    
    // MARK: - 清理旧数据
    
    private func cleanupOldData() async {
        print("🧹 [DataMigration] 清理旧数据...")
        
        // 标记迁移完成
        await storage.writeValue(Date(), forKey: "DataMigrationCompleted")
        await storage.writeValue(true, forKey: "HasMigrated")
        
        print("✅ [DataMigration] 数据清理完成")
    }
    
    // MARK: - 迁移状态检查
    
    /// 检查是否需要迁移
    public func needsMigration() async -> Bool {
        // 检查是否已经迁移过
        let hasMigrated = await storage.readValue(forKey: "HasMigrated") as? Bool ?? false
        if hasMigrated {
            print("ℹ️ [DataMigration] 数据已经迁移过")
            return false
        }
        
        // 检查是否有旧数据需要迁移
        let hasLegacyScholars = !readLegacyScholars().await.isEmpty
        let hasLegacyCitationHistory = !readLegacyCitationHistory().await.isEmpty
        
        let needsMigration = hasLegacyScholars || hasLegacyCitationHistory
        print("ℹ️ [DataMigration] 需要迁移: \(needsMigration)")
        
        return needsMigration
    }
    
    /// 强制重新迁移
    public func forceMigration() async throws {
        // 清除迁移标记
        await storage.removeData(forKey: "HasMigrated")
        await storage.removeData(forKey: "DataMigrationCompleted")
        
        // 执行迁移
        try await performMigration()
    }
}

// MARK: - 异步扩展
private extension Array {
    var await: Self {
        return self
    }
}
