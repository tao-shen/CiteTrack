import Foundation
import CoreData

// MARK: - Citing Paper Entity Extensions
extension CitingPaperEntity {
    
    /// 从CitingPaper模型创建Core Data实体
    @discardableResult
    static func create(from paper: CitingPaper, in context: NSManagedObjectContext) -> CitingPaperEntity {
        let entity = CitingPaperEntity(context: context)
        entity.update(from: paper)
        return entity
    }
    
    /// 更新实体数据
    func update(from paper: CitingPaper) {
        self.id = paper.id
        self.title = paper.title
        self.authors = paper.authors.joined(separator: "|||")  // 使用分隔符存储数组
        self.year = paper.year.map { Int16($0) } ?? 0
        self.venue = paper.venue
        self.citationCount = paper.citationCount.map { Int32($0) } ?? 0
        self.abstract_ = paper.abstract
        self.scholarUrl = paper.scholarUrl
        self.pdfUrl = paper.pdfUrl
        self.citedScholarId = paper.citedScholarId
        self.fetchedAt = paper.fetchedAt
    }
    
    /// 转换为CitingPaper模型
    func toCitingPaper() -> CitingPaper? {
        guard let id = self.id,
              let title = self.title,
              let authorsString = self.authors,
              let citedScholarId = self.citedScholarId,
              let fetchedAt = self.fetchedAt else {
            return nil
        }
        
        let authors = authorsString.split(separator: "|||").map { String($0) }
        
        return CitingPaper(
            id: id,
            title: title,
            authors: authors,
            year: self.year > 0 ? Int(self.year) : nil,
            venue: self.venue,
            citationCount: self.citationCount > 0 ? Int(self.citationCount) : nil,
            abstract: self.abstract_,
            scholarUrl: self.scholarUrl,
            pdfUrl: self.pdfUrl,
            citedScholarId: citedScholarId,
            fetchedAt: fetchedAt
        )
    }
    
    /// 获取指定学者的所有引用论文
    static func fetchRequest(for scholarId: String) -> NSFetchRequest<CitingPaperEntity> {
        let request = NSFetchRequest<CitingPaperEntity>(entityName: "CitingPaperEntity")
        request.predicate = NSPredicate(format: "citedScholarId == %@", scholarId)
        request.sortDescriptors = [NSSortDescriptor(key: "year", ascending: false)]
        return request
    }
    
    /// 获取指定时间范围内的引用论文
    static func fetchRequest(for scholarId: String, from startDate: Date, to endDate: Date) -> NSFetchRequest<CitingPaperEntity> {
        let request = NSFetchRequest<CitingPaperEntity>(entityName: "CitingPaperEntity")
        request.predicate = NSPredicate(
            format: "citedScholarId == %@ AND fetchedAt >= %@ AND fetchedAt <= %@",
            scholarId, startDate as NSDate, endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "year", ascending: false)]
        return request
    }
    
    /// 删除指定学者的所有引用论文
    static func deleteAll(for scholarId: String, in context: NSManagedObjectContext) throws {
        let request = fetchRequest(for: scholarId)
        let papers = try context.fetch(request)
        papers.forEach { context.delete($0) }
        try context.save()
    }
    
    /// 删除过期的缓存数据
    static func deleteExpired(olderThan date: Date, in context: NSManagedObjectContext) throws {
        let request = NSFetchRequest<CitingPaperEntity>(entityName: "CitingPaperEntity")
        request.predicate = NSPredicate(format: "fetchedAt < %@", date as NSDate)
        let papers = try context.fetch(request)
        papers.forEach { context.delete($0) }
        try context.save()
    }
}
