import Foundation
import CoreData
import Combine

// MARK: - Core Data Manager
public class CoreDataManager: ObservableObject {
    public static let shared = CoreDataManager()
    
    @Published public var isLoaded: Bool = false
    @Published public var loadError: Error?
    
    private init() {
        loadPersistentStores()
    }
    
    // MARK: - Core Data Stack
    
    public lazy var persistentContainer: NSPersistentContainer = {
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
                        model = NSManagedObjectModel(contentsOf: xcdatamodelURL)
                    }
                } catch {
                    print("❌ 无法读取模型目录内容: \(error)")
                }
            }
        }
        
        // 3. 如果还是没有找到，创建默认模型
        if model == nil {
            print("⚠️ 未找到预定义模型文件，创建默认模型")
            model = createDefaultModel()
        }
        
        guard let finalModel = model else {
            fatalError("❌ 无法创建 Core Data 模型")
        }
        
        let container = NSPersistentContainer(name: "CitationTrackingModel", managedObjectModel: finalModel)
        
        // 配置存储描述
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.shouldInferMappingModelAutomatically = true
        storeDescription?.shouldMigrateStoreAutomatically = true
        
        // 设置CloudKit（如果需要）
        #if os(iOS)
        if UserDefaults.standard.bool(forKey: "iCloudSyncEnabled") {
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        #endif
        
        return container
    }()
    
    public var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Background Context
    
    public func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Save Context
    
    public func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Core Data 保存成功")
            } catch {
                print("❌ Core Data 保存失败: \(error)")
                loadError = error
            }
        }
    }
    
    public func saveBackgroundContext(_ context: NSManagedObjectContext) throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPersistentStores() {
        persistentContainer.loadPersistentStores { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Core Data 加载失败: \(error)")
                    self?.loadError = error
                    self?.isLoaded = false
                } else {
                    print("✅ Core Data 加载成功")
                    self?.isLoaded = true
                    
                    // 配置视图上下文
                    self?.configureViewContext()
                }
            }
        }
    }
    
    private func configureViewContext() {
        viewContext.automaticallyMergesChangesFromParent = true
        
        // 设置合并策略
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    private func createDefaultModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // 创建 CitationHistoryEntity 实体
        let historyEntity = NSEntityDescription()
        historyEntity.name = "CitationHistoryEntity"
        historyEntity.managedObjectClassName = "CitationHistoryEntity"
        
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
        
        historyEntity.properties = [idAttribute, scholarIdAttribute, citationCountAttribute, timestampAttribute]
        
        model.entities = [historyEntity]
        
        print("✅ 创建了默认 Core Data 模型")
        return model
    }
}

// MARK: - Citation History Entity
@objc(CitationHistoryEntity)
public class CitationHistoryEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var scholarId: String?
    @NSManaged public var citationCount: Int32
    @NSManaged public var timestamp: Date?
}

extension CitationHistoryEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CitationHistoryEntity> {
        return NSFetchRequest<CitationHistoryEntity>(entityName: "CitationHistoryEntity")
    }
    
    public class func fetchRequest(for scholarId: String) -> NSFetchRequest<CitationHistoryEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "scholarId == %@", scholarId)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return request
    }
    
    public class func fetchRequest(for scholarId: String, from startDate: Date, to endDate: Date) -> NSFetchRequest<CitationHistoryEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "scholarId == %@ AND timestamp >= %@ AND timestamp <= %@",
            scholarId, startDate as NSDate, endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        return request
    }
}