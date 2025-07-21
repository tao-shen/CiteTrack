import Foundation
import CoreData

// MARK: - Core Data Errors
enum CoreDataError: Error {
    case invalidContext
    case noPersistentStores
    case entityNotFound
    case fetchFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidContext:
            return "Core Data context is invalid"
        case .noPersistentStores:
            return "No persistent stores available"
        case .entityNotFound:
            return "Entity not found in Core Data model"
        case .fetchFailed:
            return "Failed to fetch data"
        }
    }
}

@objc(CitationHistoryEntity)
public class CitationHistoryEntity: NSManagedObject {
    
}

extension CitationHistoryEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CitationHistoryEntity> {
        let request = NSFetchRequest<CitationHistoryEntity>(entityName: "CitationHistoryEntity")
        return request
    }
    
    // 安全的fetch request创建方法
    @nonobjc public class func safeFetchRequest(in context: NSManagedObjectContext) throws -> NSFetchRequest<CitationHistoryEntity> {
        // 检查context是否有效
        guard let persistentStoreCoordinator = context.persistentStoreCoordinator else {
            print("❌ NSManagedObjectContext没有persistentStoreCoordinator")
            throw CoreDataError.invalidContext
        }
        
        // 检查是否有persistent stores
        guard !persistentStoreCoordinator.persistentStores.isEmpty else {
            print("❌ 没有可用的persistent stores")
            throw CoreDataError.noPersistentStores
        }
        
        // 从context的model中查找实体
        guard let entity = NSEntityDescription.entity(forEntityName: "CitationHistoryEntity", in: context) else {
            print("❌ 无法在Core Data模型中找到CitationHistoryEntity实体")
            print("🔍 可用实体: \(context.persistentStoreCoordinator?.managedObjectModel.entities.compactMap { $0.name } ?? [])")
            throw CoreDataError.entityNotFound
        }
        
        let request = NSFetchRequest<CitationHistoryEntity>()
        request.entity = entity
        print("✅ 成功设置CitationHistoryEntity实体")
        
        return request
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var scholarId: String
    @NSManaged public var citationCount: Int32
    @NSManaged public var timestamp: Date
    @NSManaged public var source: String
    @NSManaged public var createdAt: Date
    
    // MARK: - Convenience Methods
    
    /// Fetch all citation history for a specific scholar
    static func fetchHistory(for scholarId: String, in context: NSManagedObjectContext) -> [CitationHistoryEntity] {
        do {
            let request: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
            request.predicate = NSPredicate(format: "scholarId == %@", scholarId)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            return try context.fetch(request)
        } catch {
            print("Error fetching citation history for scholar \(scholarId): \(error)")
            return []
        }
    }
    
    /// Fetch citation history for a specific scholar within a date range
    static func fetchHistory(for scholarId: String, from startDate: Date, to endDate: Date, in context: NSManagedObjectContext) -> [CitationHistoryEntity] {
        do {
            let request: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
            request.predicate = NSPredicate(
                format: "scholarId == %@ AND timestamp >= %@ AND timestamp <= %@",
                scholarId, startDate as NSDate, endDate as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            return try context.fetch(request)
        } catch {
            print("Error fetching citation history for scholar \(scholarId) in date range: \(error)")
            return []
        }
    }
    
    /// Fetch the latest citation history entry for a specific scholar
    static func fetchLatestEntry(for scholarId: String, in context: NSManagedObjectContext) -> CitationHistoryEntity? {
        do {
            let request: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
            request.predicate = NSPredicate(format: "scholarId == %@", scholarId)
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.fetchLimit = 1
            
            return try context.fetch(request).first
        } catch {
            print("Error fetching latest citation history for scholar \(scholarId): \(error)")
            return nil
        }
    }
    
    /// Delete all citation history for a specific scholar
    static func deleteHistory(for scholarId: String, in context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
        request.predicate = NSPredicate(format: "scholarId == %@", scholarId)
        
        let entities = try context.fetch(request)
        for entity in entities {
            context.delete(entity)
        }
    }
}