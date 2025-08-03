import Foundation
import CoreData

// MARK: - Core Data Manager
class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        print("🔍 开始初始化 Core Data...")
        
        // 尝试多种方式查找模型文件
        var modelURL: URL?
        var model: NSManagedObjectModel?
        
        // 1. 首先尝试加载 .momd 文件 (编译后的格式)
        modelURL = Bundle.main.url(forResource: "CitationTrackingModel", withExtension: "momd")
        if let url = modelURL {
            print("✅ 找到编译后的模型文件: \(url.path)")
            model = NSManagedObjectModel(contentsOf: url)
        }
        
        // 2. 如果没有找到 .momd，尝试加载 .xcdatamodeld 目录
        if model == nil {
            if let xcdatamodeldURL = Bundle.main.url(forResource: "CitationTrackingModel", withExtension: "xcdatamodeld") {
                print("✅ 找到源模型目录: \(xcdatamodeldURL.path)")
                
                // 查找 .xcdatamodeld 目录下的 .xcdatamodel 文件
                let fileManager = FileManager.default
                do {
                    let contents = try fileManager.contentsOfDirectory(at: xcdatamodeldURL, includingPropertiesForKeys: nil)
                    if let xcdatamodelURL = contents.first(where: { $0.pathExtension == "xcdatamodel" }) {
                        print("✅ 找到数据模型文件: \(xcdatamodelURL.path)")
                        
                        // 检查是否有contents文件
                        let contentsURL = xcdatamodelURL.appendingPathComponent("contents")
                        if fileManager.fileExists(atPath: contentsURL.path) {
                            print("✅ 找到contents文件: \(contentsURL.path)")
                            // 直接从xcdatamodel目录加载
                            model = NSManagedObjectModel(contentsOf: xcdatamodelURL)
                        } else {
                            print("❌ 未找到contents文件")
                        }
                    }
                } catch {
                    print("❌ 无法读取模型目录内容: \(error)")
                }
            }
        }
        
        // 3. 最后尝试直接从Bundle创建
        if model == nil {
            print("🔍 尝试从Bundle直接创建模型...")
            if let bundleModel = NSManagedObjectModel.mergedModel(from: [Bundle.main]) {
                print("✅ 从Bundle成功创建模型")
                model = bundleModel
            }
        }
        
        // 4. 如果所有方法都失败，尝试手动创建模型
        if model == nil {
            print("🔍 尝试手动创建Core Data模型...")
            model = createManualModel()
        }
        
        guard let finalModel = model else {
            print("❌ 无法加载或创建 Core Data 模型")
            print("📁 Bundle 路径: \(Bundle.main.bundlePath)")
            print("📁 Bundle 资源: \(Bundle.main.urls(forResourcesWithExtension: "momd", subdirectory: nil) ?? [])")
            print("📁 xcdatamodeld 资源: \(Bundle.main.urls(forResourcesWithExtension: "xcdatamodeld", subdirectory: nil) ?? [])")
            
            // 创建一个基本的内存模型以避免应用崩溃
            let fallbackModel = createFallbackModel()
            let container = NSPersistentContainer(name: "CitationTrackingModel_Fallback", managedObjectModel: fallbackModel)
            
            // 使用内存存储，不影响应用的主要功能
            let storeDescription = NSPersistentStoreDescription()
            storeDescription.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [storeDescription]
            
            container.loadPersistentStores { _, error in
                if let error = error {
                    print("❌ 即使是回退模型也加载失败: \(error)")
                } else {
                    print("✅ 使用回退Core Data模型 (仅内存)")
                }
            }
            
            container.viewContext.automaticallyMergesChangesFromParent = true
            return container
        }
        
        print("✅ 成功加载 Core Data 模型")
        print("📊 实体数量: \(finalModel.entities.count)")
        for entity in finalModel.entities {
            print("  - \(entity.name ?? "未知实体")")
        }
        
        // 验证模型是否包含我们需要的实体
        if finalModel.entities.isEmpty {
            print("⚠️ 警告: 模型没有实体，使用手动创建的模型")
            let manualModel = createManualModel()
            if let manualModel = manualModel {
                print("✅ 手动模型创建成功，包含 \(manualModel.entities.count) 个实体")
                model = manualModel
            }
        }
        
        // 使用最终的模型
        let finalModelToUse = model!
        
        // 创建容器
        let container = NSPersistentContainer(name: "CitationTrackingModel", managedObjectModel: finalModelToUse)
        
        // 配置存储描述符
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            print("📍 存储配置: 自动迁移已启用")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                print("❌ Core Data 加载失败: \(error)")
                print("📍 存储位置: \(storeDescription.url?.path ?? "未知")")
                
                // 如果是文件损坏，尝试删除并重新创建
                if let storeURL = storeDescription.url,
                   FileManager.default.fileExists(atPath: storeURL.path) {
                    print("🗑️ 尝试删除损坏的存储文件...")
                    do {
                        try FileManager.default.removeItem(at: storeURL)
                        print("✅ 成功删除损坏的存储文件")
                        
                        // 重新尝试加载
                        container.loadPersistentStores { _, retryError in
                            if let retryError = retryError {
                                print("❌ 重试失败: \(retryError)")
                                print("🔄 切换到内存存储模式以确保应用继续运行")
                                
                                // 最后的回退：使用内存存储
                                let memoryDescription = NSPersistentStoreDescription()
                                memoryDescription.type = NSInMemoryStoreType
                                container.persistentStoreDescriptions = [memoryDescription]
                                
                                container.loadPersistentStores { _, finalError in
                                    if let finalError = finalError {
                                        print("❌ 即使内存存储也失败: \(finalError)")
                                    } else {
                                        print("✅ 使用内存存储模式")
                                    }
                                }
                            } else {
                                print("✅ Core Data 重新创建成功")
                            }
                        }
                    } catch {
                        print("❌ 删除存储文件失败: \(error)")
                        print("🔄 最后尝试：使用内存存储模式")
                        
                        // 即使删除失败，也尝试内存存储
                        let memoryDescription = NSPersistentStoreDescription()
                        memoryDescription.type = NSInMemoryStoreType
                        container.persistentStoreDescriptions = [memoryDescription]
                        
                        container.loadPersistentStores { _, memoryError in
                            if let memoryError = memoryError {
                                print("❌ 内存存储也失败: \(memoryError)")
                                print("⚠️ Core Data 功能将被禁用，应用将在受限模式下运行")
                            } else {
                                print("✅ 使用内存存储模式运行")
                            }
                        }
                    }
                } else {
                    // 作为最后的手段，使用内存存储
                    print("🔄 尝试内存存储作为最后的回退方案")
                    let memoryDescription = NSPersistentStoreDescription()
                    memoryDescription.type = NSInMemoryStoreType
                    container.persistentStoreDescriptions = [memoryDescription]
                    
                    container.loadPersistentStores { _, memoryError in
                        if let memoryError = memoryError {
                            print("❌ 所有Core Data存储方式都失败: \(memoryError)")
                            print("⚠️ 应用将在没有数据持久化的情况下运行")
                        } else {
                            print("✅ 成功回退到内存存储模式")
                        }
                    }
                }
            } else {
                print("✅ Core Data 加载成功")
                print("📍 存储位置: \(storeDescription.url?.path ?? "未知")")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    // MARK: - Manual Model Creation
    private func createManualModel() -> NSManagedObjectModel? {
        print("🔧 手动创建 Core Data 模型...")
        
        let model = NSManagedObjectModel()
        
        // 创建 CitationHistoryEntity 实体
        let entity = NSEntityDescription()
        entity.name = "CitationHistoryEntity"
        entity.managedObjectClassName = "CitationHistoryEntity"
        
        // 创建属性
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        let scholarIdAttribute = NSAttributeDescription()
        scholarIdAttribute.name = "scholarId"
        scholarIdAttribute.attributeType = .stringAttributeType
        scholarIdAttribute.isOptional = false
        
        let citationCountAttribute = NSAttributeDescription()
        citationCountAttribute.name = "citationCount"
        citationCountAttribute.attributeType = .integer32AttributeType
        citationCountAttribute.isOptional = false
        citationCountAttribute.defaultValue = 0
        
        let timestampAttribute = NSAttributeDescription()
        timestampAttribute.name = "timestamp"
        timestampAttribute.attributeType = .dateAttributeType
        timestampAttribute.isOptional = false
        
        let sourceAttribute = NSAttributeDescription()
        sourceAttribute.name = "source"
        sourceAttribute.attributeType = .stringAttributeType
        sourceAttribute.isOptional = false
        sourceAttribute.defaultValue = "automatic"
        
        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = false
        
        entity.properties = [
            idAttribute,
            scholarIdAttribute,
            citationCountAttribute,
            timestampAttribute,
            sourceAttribute,
            createdAtAttribute
        ]
        
        model.entities = [entity]
        
        print("✅ 手动模型创建成功")
        return model
    }
    
    // MARK: - Fallback Model Creation
    private func createFallbackModel() -> NSManagedObjectModel {
        print("🔧 创建回退 Core Data 模型...")
        
        // 创建一个最简单的模型，仅用于避免应用崩溃
        let model = NSManagedObjectModel()
        
        // 创建一个简单的实体，即使数据无法持久化，也能让应用运行
        let entity = NSEntityDescription()
        entity.name = "CitationHistoryEntity"
        entity.managedObjectClassName = "CitationHistoryEntity"
        
        // 最基本的属性
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = true
        
        entity.properties = [idAttribute]
        model.entities = [entity]
        
        print("✅ 回退模型创建成功 (功能受限)")
        return model
    }
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Save Context
    func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
                handleCoreDataError(nsError)
            }
        }
    }
    
    func saveBackgroundContext(_ context: NSManagedObjectContext) {
        context.perform {
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    let nsError = error as NSError
                    print("Background context save error: \(nsError), \(nsError.userInfo)")
                    self.handleCoreDataError(nsError)
                }
            }
        }
    }
    
    // MARK: - Error Handling
    private func handleCoreDataError(_ error: NSError) {
        // Log error details
        print("Core Data Error Details:")
        print("Code: \(error.code)")
        print("Domain: \(error.domain)")
        print("Description: \(error.localizedDescription)")
        print("User Info: \(error.userInfo)")
        
        // Post notification for error handling in UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .coreDataError,
                object: nil,
                userInfo: ["error": error]
            )
        }
    }
    
    // MARK: - Database Migration Support
    func performMigrationIfNeeded() {
        let storeURL = persistentContainer.persistentStoreDescriptions.first?.url
        
        guard let url = storeURL else { return }
        
        // Check if store exists
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: url,
                options: nil
            )
            
            let model = persistentContainer.managedObjectModel
            
            if !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
                print("Core Data model is not compatible, migration needed")
                // Migration will be handled automatically by Core Data
            }
        } catch {
            print("Error checking Core Data compatibility: \(error)")
        }
    }
    
    // MARK: - Cleanup and Maintenance
    func performMaintenanceTasks() {
        let backgroundContext = newBackgroundContext()
        
        backgroundContext.perform { [weak self] in
            self?.cleanupOldData(in: backgroundContext)
            self?.optimizeDatabase(in: backgroundContext)
        }
    }
    
    private func cleanupOldData(in context: NSManagedObjectContext) {
        // Remove citation history older than 2 years (configurable retention policy)
        let retentionPeriod: TimeInterval = 2 * 365 * 24 * 60 * 60 // 2 years in seconds
        let cutoffDate = Date().addingTimeInterval(-retentionPeriod)
        
        do {
            let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
            fetchRequest.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
            
            let oldEntries = try context.fetch(fetchRequest)
            for entry in oldEntries {
                context.delete(entry)
            }
            
            if context.hasChanges {
                try context.save()
                print("Cleaned up \(oldEntries.count) old citation history entries")
            }
        } catch {
            print("Error cleaning up old data: \(error)")
            // Core Data 问题时不应该崩溃应用，只记录错误
        }
    }
    
    private func optimizeDatabase(in context: NSManagedObjectContext) {
        // Perform database optimization tasks
        // Reset the context to free up memory
        context.reset()
        
        // The persistent store coordinator will handle optimization automatically
        print("Database optimization completed")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let coreDataError = Notification.Name("CoreDataError")
    static let coreDataMigrationCompleted = Notification.Name("CoreDataMigrationCompleted")
}

