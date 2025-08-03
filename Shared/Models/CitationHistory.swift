import Foundation
import CoreData

// MARK: - Citation History Model
public struct CitationHistory: Codable, Identifiable {
    public let id: UUID
    public let scholarId: String
    public let citationCount: Int
    public let timestamp: Date
    
    public init(scholarId: String, citationCount: Int, timestamp: Date = Date()) {
        self.id = UUID()
        self.scholarId = scholarId
        self.citationCount = citationCount
        self.timestamp = timestamp
    }
    
    public init(id: UUID, scholarId: String, citationCount: Int, timestamp: Date) {
        self.id = id
        self.scholarId = scholarId
        self.citationCount = citationCount
        self.timestamp = timestamp
    }
}

// MARK: - Core Data Extensions
public extension CitationHistory {
    @discardableResult
    func toCoreDataEntity(in context: NSManagedObjectContext) -> CitationHistoryEntity {
        let entity = CitationHistoryEntity(context: context)
        entity.id = self.id
        entity.scholarId = self.scholarId
        entity.citationCount = Int32(self.citationCount)
        entity.timestamp = self.timestamp
        return entity
    }
    
    static func fromCoreDataEntity(_ entity: CitationHistoryEntity) -> CitationHistory? {
        guard let id = entity.id,
              let scholarId = entity.scholarId,
              let timestamp = entity.timestamp else {
            return nil
        }
        
        return CitationHistory(
            id: id,
            scholarId: scholarId,
            citationCount: Int(entity.citationCount),
            timestamp: timestamp
        )
    }
}

// MARK: - Chart Data Conversion
public extension CitationHistory {
    var chartPoint: (x: Date, y: Double) {
        return (x: timestamp, y: Double(citationCount))
    }
}

// MARK: - Array Extensions
public extension Array where Element == CitationHistory {
    var chartData: [(x: Date, y: Double)] {
        return self.map { $0.chartPoint }.sorted { $0.x < $1.x }
    }
    
    func filterByDateRange(from startDate: Date, to endDate: Date) -> [CitationHistory] {
        return self.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }
    
    func groupedByDay() -> [Date: [CitationHistory]] {
        let calendar = Calendar.current
        return Dictionary(grouping: self) { history in
            calendar.startOfDay(for: history.timestamp)
        }
    }
    
    func latestEntryPerDay() -> [CitationHistory] {
        return groupedByDay().values.compactMap { dayEntries in
            dayEntries.max { $0.timestamp < $1.timestamp }
        }.sorted { $0.timestamp < $1.timestamp }
    }
}