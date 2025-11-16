import Foundation
import CoreData

// MARK: - Citing Author Entity Extensions
extension CitingAuthorEntity {
    
    /// 从CitingAuthor模型创建Core Data实体
    @discardableResult
    static func create(from author: CitingAuthor, in context: NSManagedObjectContext) -> CitingAuthorEntity {
        let entity = CitingAuthorEntity(context: context)
        entity.update(from: author)
        return entity
    }
    
    /// 更新实体数据
    func update(from author: CitingAuthor) {
        self.id = author.id
        self.name = author.name
        self.affiliation = author.affiliation
        self.interests = author.interests?.joined(separator: "|||")  // 使用分隔符存储数组
        self.citationCount = author.citationCount.map { Int32($0) } ?? 0
        self.hIndex = author.hIndex.map { Int16($0) } ?? 0
        self.citingPaperCount = Int32(author.citingPaperCount)
        self.scholarUrl = author.scholarUrl
    }
    
    /// 转换为CitingAuthor模型
    func toCitingAuthor() -> CitingAuthor? {
        guard let id = self.id,
              let name = self.name,
              let scholarUrl = self.scholarUrl else {
            return nil
        }
        
        let interests = self.interests?.split(separator: "|||").map { String($0) }
        
        return CitingAuthor(
            id: id,
            name: name,
            affiliation: self.affiliation,
            interests: interests,
            citationCount: self.citationCount > 0 ? Int(self.citationCount) : nil,
            hIndex: self.hIndex > 0 ? Int(self.hIndex) : nil,
            citingPaperCount: Int(self.citingPaperCount),
            scholarUrl: scholarUrl
        )
    }
    
    /// 获取所有引用作者
    static func fetchRequest() -> NSFetchRequest<CitingAuthorEntity> {
        let request = NSFetchRequest<CitingAuthorEntity>(entityName: "CitingAuthorEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "citingPaperCount", ascending: false)]
        return request
    }
    
    /// 根据ID获取作者
    static func fetchRequest(withId id: String) -> NSFetchRequest<CitingAuthorEntity> {
        let request = NSFetchRequest<CitingAuthorEntity>(entityName: "CitingAuthorEntity")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return request
    }
    
    /// 获取引用次数最多的作者
    static func fetchTopAuthors(limit: Int = 10) -> NSFetchRequest<CitingAuthorEntity> {
        let request = NSFetchRequest<CitingAuthorEntity>(entityName: "CitingAuthorEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "citingPaperCount", ascending: false)]
        request.fetchLimit = limit
        return request
    }
    
    /// 删除所有引用作者
    static func deleteAll(in context: NSManagedObjectContext) throws {
        let request = fetchRequest()
        let authors = try context.fetch(request)
        authors.forEach { context.delete($0) }
        try context.save()
    }
}
