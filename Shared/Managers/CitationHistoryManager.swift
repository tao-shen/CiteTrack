import Foundation
import CoreData
import Combine

// MARK: - Citation History Manager
public class CitationHistoryManager: ObservableObject {
    public static let shared = CitationHistoryManager()
    
    private let coreDataManager = CoreDataManager.shared
    private let backgroundQueue = DispatchQueue(label: "com.citetrack.historymanager", qos: .utility)
    
    @Published public var isLoading: Bool = false
    @Published public var lastError: Error?
    
    private init() {
        print("📝 CitationHistoryManager: 初始化")
    }
    
    // MARK: - Save Operations
    
    /// Save a new citation history entry
    public func saveHistoryEntry(_ entry: CitationHistory, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        backgroundQueue.async {
            let context = self.coreDataManager.newBackgroundContext()
            context.perform {
                _ = entry.toCoreDataEntity(in: context)
                do {
                    try self.coreDataManager.saveBackgroundContext(context)
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                    print("✅ 保存引用历史记录成功: \(entry.scholarId) - \(entry.citationCount)")
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    print("❌ 保存引用历史记录失败: \(error)")
                }
            }
        }
    }
    
    /// Save history if citation count has changed
    public func saveHistoryIfChanged(scholarId: String, citationCount: Int, completion: @escaping (Bool) -> Void = { _ in }) {
        backgroundQueue.async {
            // 检查最新记录
            self.getLatestEntry(for: scholarId) { result in
                switch result {
                case .success(let latestEntry):
                    if let latest = latestEntry, latest.citationCount == citationCount {
                        // 没有变化，不保存
                        completion(false)
                    } else {
                        // 有变化或没有历史记录，保存新记录
                        let newEntry = CitationHistory(
                            scholarId: scholarId,
                            citationCount: citationCount,
                            timestamp: Date()
                        )
                        self.saveHistoryEntry(newEntry) { saveResult in
                            completion(saveResult.isSuccess)
                        }
                    }
                    
                case .failure:
                    // 获取失败，仍然尝试保存
                    let newEntry = CitationHistory(
                        scholarId: scholarId,
                        citationCount: citationCount,
                        timestamp: Date()
                    )
                    self.saveHistoryEntry(newEntry) { saveResult in
                        completion(saveResult.isSuccess)
                    }
                }
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    /// Get all history for a scholar
    public func getAllHistory(for scholarId: String, completion: @escaping (Result<[CitationHistory], Error>) -> Void) {
        backgroundQueue.async {
            let context = self.coreDataManager.newBackgroundContext()
            context.perform {
                let request = CitationHistoryEntity.fetchRequest(for: scholarId)
                
                do {
                    let entities = try context.fetch(request)
                    let histories = entities.compactMap { CitationHistory.fromCoreDataEntity($0) }
                    
                    DispatchQueue.main.async {
                        completion(.success(histories))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// Get history for a scholar within date range
    public func getHistory(
        for scholarId: String,
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (Result<[CitationHistory], Error>) -> Void
    ) {
        backgroundQueue.async {
            let context = self.coreDataManager.newBackgroundContext()
            context.perform {
                let request = CitationHistoryEntity.fetchRequest(for: scholarId, from: startDate, to: endDate)
                
                do {
                    let entities = try context.fetch(request)
                    let histories = entities.compactMap { CitationHistory.fromCoreDataEntity($0) }
                    
                    DispatchQueue.main.async {
                        completion(.success(histories))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// Get latest history entry for a scholar
    public func getLatestEntry(for scholarId: String, completion: @escaping (Result<CitationHistory?, Error>) -> Void) {
        backgroundQueue.async {
            let context = self.coreDataManager.newBackgroundContext()
            context.perform {
                let request = CitationHistoryEntity.fetchRequest(for: scholarId)
                request.fetchLimit = 1
                request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                
                do {
                    let entities = try context.fetch(request)
                    let history = entities.first.flatMap { CitationHistory.fromCoreDataEntity($0) }
                    
                    DispatchQueue.main.async {
                        completion(.success(history))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// Get recent changes for all scholars
    public func getRecentChanges(since date: Date, completion: @escaping (Result<[CitationChange], Error>) -> Void) {
        backgroundQueue.async {
            let context = self.coreDataManager.newBackgroundContext()
            context.perform {
                let request: NSFetchRequest<CitationHistoryEntity> = CitationHistoryEntity.fetchRequest()
                request.predicate = NSPredicate(format: "timestamp >= %@", date as NSDate)
                request.sortDescriptors = [
                    NSSortDescriptor(key: "scholarId", ascending: true),
                    NSSortDescriptor(key: "timestamp", ascending: true)
                ]
                
                do {
                    let entities = try context.fetch(request)
                    let changes = self.calculateChanges(from: entities)
                    
                    DispatchQueue.main.async {
                        completion(.success(changes))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Get statistics for a scholar
    public func getStatistics(for scholarId: String, completion: @escaping (Result<ScholarStatistics, Error>) -> Void) {
        getAllHistory(for: scholarId) { result in
            switch result {
            case .success(let histories):
                let stats = ScholarStatistics(from: histories)
                completion(.success(stats))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Data Management
    
    /// Delete all history for a scholar using efficient batch delete
    public func deleteHistory(for scholarId: String, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        backgroundQueue.async {
            let context = self.coreDataManager.newBackgroundContext()
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CitationHistoryEntity")
                    fetchRequest.predicate = NSPredicate(format: "scholarId == %@", scholarId)
                    let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    batchDelete.resultType = .resultTypeCount

                    let result = try context.execute(batchDelete) as? NSBatchDeleteResult
                    let count = result?.result as? Int ?? 0

                    // Merge changes to viewContext so UI updates
                    self.coreDataManager.viewContext.perform {
                        self.coreDataManager.viewContext.refreshAllObjects()
                    }

                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                    print("✅ 批量删除学者 \(scholarId) 的 \(count) 条历史记录成功")
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    print("❌ 删除学者 \(scholarId) 的历史记录失败: \(error)")
                }
            }
        }
    }

    /// Delete old history entries using efficient batch delete
    public func cleanupOldEntries(keepDays: Int = 365, completion: @escaping (Result<Int, Error>) -> Void = { _ in }) {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(keepDays * 24 * 60 * 60))

        backgroundQueue.async {
            let context = self.coreDataManager.newBackgroundContext()
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "CitationHistoryEntity")
                    fetchRequest.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)
                    let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    batchDelete.resultType = .resultTypeCount

                    let result = try context.execute(batchDelete) as? NSBatchDeleteResult
                    let deletedCount = result?.result as? Int ?? 0

                    self.coreDataManager.viewContext.perform {
                        self.coreDataManager.viewContext.refreshAllObjects()
                    }

                    DispatchQueue.main.async {
                        completion(.success(deletedCount))
                    }
                    print("✅ 批量清理旧历史记录成功，删除 \(deletedCount) 条记录")
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    print("❌ 清理旧历史记录失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - Export
    
    /// Export all history data
    public func exportAllHistory(format: ExportFormat, completion: @escaping (Result<String, Error>) -> Void) {
        backgroundQueue.async {
            let context = self.coreDataManager.newBackgroundContext()
            context.perform {
                let request: NSFetchRequest<CitationHistoryEntity> = CitationHistoryEntity.fetchRequest()
                request.sortDescriptors = [
                    NSSortDescriptor(key: "scholarId", ascending: true),
                    NSSortDescriptor(key: "timestamp", ascending: true)
                ]
                
                do {
                    let entities = try context.fetch(request)
                    let histories = entities.compactMap { CitationHistory.fromCoreDataEntity($0) }
                    
                    let exportString: String
                    switch format {
                    case .csv:
                        exportString = self.exportToCSV(histories)
                    case .json:
                        exportString = self.exportToJSON(histories)
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(exportString))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateChanges(from entities: [CitationHistoryEntity]) -> [CitationChange] {
        var changes: [CitationChange] = []
        var scholarGroups: [String: [CitationHistoryEntity]] = [:]
        
        // 按学者分组
        for entity in entities {
            guard let scholarId = entity.scholarId else { continue }
            if scholarGroups[scholarId] == nil {
                scholarGroups[scholarId] = []
            }
            scholarGroups[scholarId]?.append(entity)
        }
        
        // 计算每个学者的变化
        for (scholarId, entities) in scholarGroups {
            let sortedEntities = entities.sorted { 
                ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) 
            }
            
            for i in 1..<sortedEntities.count {
                let current = sortedEntities[i]
                let previous = sortedEntities[i-1]
                
                let change = CitationChange(
                    id: UUID(),
                    scholarId: scholarId,
                    scholarName: "Scholar \(scholarId.prefix(8))", // 这里应该从设置中获取真实名字
                    change: Int(current.citationCount - previous.citationCount),
                    date: current.timestamp ?? Date(),
                    oldCount: Int(previous.citationCount),
                    newCount: Int(current.citationCount)
                )
                
                if change.change != 0 {
                    changes.append(change)
                }
            }
        }
        
        return changes.sorted { $0.date > $1.date }
    }
    
    private func exportToCSV(_ histories: [CitationHistory]) -> String {
        var csv = "Scholar ID,Citation Count,Date\n"
        
        for history in histories {
            let dateString = DateFormatter.export.string(from: history.timestamp)
            csv += "\(history.scholarId),\(history.citationCount),\(dateString)\n"
        }
        
        return csv
    }
    
    private func exportToJSON(_ histories: [CitationHistory]) -> String {
        let exportData = ExportData(scholars: [], history: histories)
        
        do {
            let jsonData = try JSONEncoder().encode(exportData)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

// MARK: - Supporting Types

public struct CitationChange: Identifiable {
    public let id: UUID
    public let scholarId: String
    public let scholarName: String
    public let change: Int
    public let date: Date
    public let oldCount: Int
    public let newCount: Int
    
    public init(id: UUID = UUID(), scholarId: String, scholarName: String, change: Int, date: Date, oldCount: Int, newCount: Int) {
        self.id = id
        self.scholarId = scholarId
        self.scholarName = scholarName
        self.change = change
        self.date = date
        self.oldCount = oldCount
        self.newCount = newCount
    }
}

public struct ScholarStatistics {
    public let totalEntries: Int
    public let firstRecordDate: Date?
    public let lastRecordDate: Date?
    public let currentCitations: Int
    public let totalGrowth: Int
    public let averageGrowthPerDay: Double
    public let maxCitations: Int
    public let minCitations: Int
    
    public init(from histories: [CitationHistory]) {
        totalEntries = histories.count
        firstRecordDate = histories.first?.timestamp
        lastRecordDate = histories.last?.timestamp
        currentCitations = histories.last?.citationCount ?? 0
        
        let citations = histories.map { $0.citationCount }
        maxCitations = citations.max() ?? 0
        minCitations = citations.min() ?? 0
        totalGrowth = currentCitations - (histories.first?.citationCount ?? 0)
        
        if let first = firstRecordDate, let last = lastRecordDate, last > first {
            let daysDifference = last.timeIntervalSince(first) / (24 * 60 * 60)
            averageGrowthPerDay = daysDifference > 0 ? Double(totalGrowth) / daysDifference : 0
        } else {
            averageGrowthPerDay = 0
        }
    }
}

// MARK: - Result Extension
extension Result {
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
}