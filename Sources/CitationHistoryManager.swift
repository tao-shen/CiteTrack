import Foundation
import CoreData

// MARK: - Export Format
enum ExportFormat: String, CaseIterable {
    case csv = "csv"
    case json = "json"
    
    var displayName: String {
        switch self {
        case .csv:
            return "CSV"
        case .json:
            return "JSON"
        }
    }
    
    var fileExtension: String {
        return self.rawValue
    }
    
    var mimeType: String {
        switch self {
        case .csv:
            return "text/csv"
        case .json:
            return "application/json"
        }
    }
}

// MARK: - Citation History Manager
class CitationHistoryManager {
    static let shared = CitationHistoryManager()
    
    private let coreDataManager = CoreDataManager.shared
    private let backgroundQueue = DispatchQueue(label: "com.citetrack.historymanager", qos: .utility)
    
    private init() {
        print("📝 CitationHistoryManager: 初始化 (Core Data暂时禁用)")
    }
    
    // MARK: - Save Operations
    
    /// Save a new citation history entry
    func saveHistoryEntry(_ entry: CitationHistory, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            _ = entry.toCoreDataEntity(in: context)
            do {
                try context.save()
                print("✅ 已保存历史记录 (scholar: \(entry.scholarId), citations: \(entry.citationCount))")
                completion(.success(()))
            } catch {
                print("❌ 保存历史记录失败: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    /// Save multiple citation history entries in batch
    func saveHistoryEntries(_ entries: [CitationHistory], completion: @escaping (Result<Int, Error>) -> Void = { _ in }) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            for entry in entries {
                _ = entry.toCoreDataEntity(in: context)
            }
            do {
                try context.save()
                print("✅ 批量保存 \(entries.count) 条历史记录")
                completion(.success(entries.count))
            } catch {
                print("❌ 批量保存历史记录失败: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    /// Get citation history for a specific scholar
    func getHistory(for scholarId: String, completion: @escaping (Result<[CitationHistory], Error>) -> Void) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.predicate = NSPredicate(format: "scholarId == %@", scholarId)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                
                let entities = try context.fetch(fetchRequest)
                let histories = entities.compactMap { entity in
                    CitationHistory.fromCoreDataEntity(entity)
                }
                
                DispatchQueue.main.async {
                    completion(.success(histories))
                }
            } catch {
                print("❌ 获取历史数据失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get citation history for a specific scholar within a time range
    func getHistory(for scholarId: String, in timeRange: TimeRange, completion: @escaping (Result<[CitationHistory], Error>) -> Void) {
        let (startDate, endDate) = timeRange.dateRange
        getHistory(for: scholarId, from: startDate, to: endDate, completion: completion)
    }
    
    /// Get citation history for a specific scholar within custom date range
    func getHistory(for scholarId: String, from startDate: Date, to endDate: Date, completion: @escaping (Result<[CitationHistory], Error>) -> Void) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.predicate = NSPredicate(format: "scholarId == %@ AND timestamp >= %@ AND timestamp <= %@", 
                                                   scholarId, startDate as NSDate, endDate as NSDate)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                
                let entities = try context.fetch(fetchRequest)
                let histories = entities.compactMap { entity in
                    CitationHistory.fromCoreDataEntity(entity)
                }
                
                DispatchQueue.main.async {
                    completion(.success(histories))
                }
            } catch {
                print("❌ 获取指定时间范围历史数据失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get the latest citation history entry for a scholar
    func getLatestEntry(for scholarId: String, completion: @escaping (Result<CitationHistory?, Error>) -> Void) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.predicate = NSPredicate(format: "scholarId == %@", scholarId)
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
                fetchRequest.fetchLimit = 1
                
                let entities = try context.fetch(fetchRequest)
                let latestHistory = entities.first.flatMap { CitationHistory.fromCoreDataEntity($0) }
                
                DispatchQueue.main.async {
                    completion(.success(latestHistory))
                }
            } catch {
                print("❌ 获取最新历史记录失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Get all citation history entries (for export or analysis)
    func getAllHistory(completion: @escaping (Result<[CitationHistory], Error>) -> Void) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.sortDescriptors = [
                    NSSortDescriptor(key: "scholarId", ascending: true),
                    NSSortDescriptor(key: "timestamp", ascending: false)
                ]
                
                let entities = try context.fetch(fetchRequest)
                let histories = entities.compactMap { entity in
                    CitationHistory.fromCoreDataEntity(entity)
                }
                
                DispatchQueue.main.async {
                    completion(.success(histories))
                }
            } catch {
                print("❌ 获取全部历史数据失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Delete Operations
    
    /// Delete all citation history for a specific scholar
    func deleteHistory(for scholarId: String, completion: @escaping (Result<Int, Error>) -> Void = { _ in }) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.predicate = NSPredicate(format: "scholarId == %@", scholarId)
                
                let entities = try context.fetch(fetchRequest)
                let deleteCount = entities.count
                
                for entity in entities {
                    context.delete(entity)
                }
                
                try context.save()
                print("✅ 删除学者 \(scholarId) 的 \(deleteCount) 条历史记录")
                
                DispatchQueue.main.async {
                    completion(.success(deleteCount))
                }
            } catch {
                print("❌ 删除历史记录失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Delete citation history entries older than specified date
    func deleteHistoryOlderThan(_ date: Date, completion: @escaping (Result<Int, Error>) -> Void = { _ in }) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.predicate = NSPredicate(format: "timestamp < %@", date as NSDate)
                
                let entities = try context.fetch(fetchRequest)
                let deleteCount = entities.count
                
                for entity in entities {
                    context.delete(entity)
                }
                
                try context.save()
                print("✅ 删除 \(deleteCount) 条旧历史记录 (早于 \(date))")
                
                DispatchQueue.main.async {
                    completion(.success(deleteCount))
                }
            } catch {
                print("❌ 删除旧历史记录失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Data Repair Operations
    
    /// Update a specific citation history entry
    func updateHistoryEntry(_ entry: CitationHistory, completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
                fetchRequest.fetchLimit = 1
                
                let entities = try context.fetch(fetchRequest)
                guard let entity = entities.first else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "CitationHistoryManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Entry not found"])))
                    }
                    return
                }
                
                // Update the entity
                entity.citationCount = Int32(entry.citationCount)
                entity.timestamp = entry.timestamp
                entity.source = entry.source.rawValue
                
                try context.save()
                print("✅ 更新历史记录条目: \(entry.id)")
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                print("❌ 更新历史记录条目失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Delete specific citation history entries
    func deleteHistoryEntries(_ entries: [CitationHistory], completion: @escaping (Result<Int, Error>) -> Void = { _ in }) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let entryIds = entries.map { $0.id }
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.predicate = NSPredicate(format: "id IN %@", entryIds)
                
                let entities = try context.fetch(fetchRequest)
                let deleteCount = entities.count
                
                for entity in entities {
                    context.delete(entity)
                }
                
                try context.save()
                print("✅ 删除 \(deleteCount) 条历史记录条目")
                
                DispatchQueue.main.async {
                    completion(.success(deleteCount))
                }
            } catch {
                print("❌ 删除历史记录条目失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Delete all citation history entries after a specific date
    func deleteHistoryAfter(_ date: Date, for scholarId: String, completion: @escaping (Result<Int, Error>) -> Void = { _ in }) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.predicate = NSPredicate(format: "scholarId == %@ AND timestamp > %@", scholarId, date as NSDate)
                
                let entities = try context.fetch(fetchRequest)
                let deleteCount = entities.count
                
                for entity in entities {
                    context.delete(entity)
                }
                
                try context.save()
                print("✅ 删除 \(deleteCount) 条历史记录 (晚于 \(date))")
                
                DispatchQueue.main.async {
                    completion(.success(deleteCount))
                }
            } catch {
                print("❌ 删除历史记录失败: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Smart Saving
    
    /// Save citation history only if data has changed
    func saveHistoryIfChanged(scholarId: String, citationCount: Int, source: CitationHistory.DataSource = .automatic, completion: @escaping (Bool) -> Void = { _ in }) {
        // Get the latest entry for this scholar
        getLatestEntry(for: scholarId) { [weak self] result in
            switch result {
            case .success(let latestEntry):
                // Check if data has actually changed
                if let latest = latestEntry {
                    if latest.citationCount != citationCount {
                        // Data has changed - save new entry
                        let historyEntry = CitationHistory(
                            scholarId: scholarId,
                            citationCount: citationCount,
                            source: source
                        )
                        
                        self?.saveHistoryEntry(historyEntry) { saveResult in
                            switch saveResult {
                            case .success:
                                completion(true) // Data was saved
                            case .failure(let error):
                                print("❌ Failed to save citation history for scholar \(scholarId): \(error)")
                                completion(false) // Save failed
                            }
                        }
                    } else {
                        // Data unchanged - don't save
                        completion(false) // Data was not saved
                    }
                } else {
                    // No previous entry - this is the first time, so save it
                    let historyEntry = CitationHistory(
                        scholarId: scholarId,
                        citationCount: citationCount,
                        source: source
                    )
                    
                    self?.saveHistoryEntry(historyEntry) { saveResult in
                        switch saveResult {
                        case .success:
                            completion(true) // First entry saved
                        case .failure(let error):
                            print("❌ Failed to save initial citation history for scholar \(scholarId): \(error)")
                            completion(false) // Save failed
                        }
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to get latest entry for scholar \(scholarId): \(error)")
                // On error, default to saving (conservative approach)
                let historyEntry = CitationHistory(
                    scholarId: scholarId,
                    citationCount: citationCount,
                    source: source
                )
                
                self?.saveHistoryEntry(historyEntry) { saveResult in
                    switch saveResult {
                    case .success:
                        completion(true) // Data was saved (fallback)
                    case .failure(let saveError):
                        print("❌ Failed to save fallback citation history for scholar \(scholarId): \(saveError)")
                        completion(false) // Save failed
                    }
                }
            }
        }
    }
    
    /// Force save citation history (for manual operations)
    func forceSaveHistoryEntry(scholarId: String, citationCount: Int, source: CitationHistory.DataSource = .manual, completion: @escaping (Bool) -> Void = { _ in }) {
        let historyEntry = CitationHistory(
            scholarId: scholarId,
            citationCount: citationCount,
            source: source
        )
        
        saveHistoryEntry(historyEntry) { saveResult in
            switch saveResult {
            case .success:
                print("✅ Forced save citation history for scholar \(scholarId): \(citationCount) citations")
                completion(true)
            case .failure(let error):
                print("❌ Failed to force save citation history for scholar \(scholarId): \(error)")
                completion(false)
            }
        }
    }
    
    // MARK: - Statistics
    
    /// Get citation statistics for a specific scholar
    func getStatistics(for scholarId: String, in timeRange: TimeRange, completion: @escaping (Result<CitationStatistics, Error>) -> Void) {
        let (startDate, endDate) = timeRange.dateRange
        getStatistics(for: scholarId, from: startDate, to: endDate, completion: completion)
    }
    
    /// Get citation statistics for a specific scholar within custom date range
    func getStatistics(for scholarId: String, from startDate: Date, to endDate: Date, completion: @escaping (Result<CitationStatistics, Error>) -> Void) {
        getHistory(for: scholarId, from: startDate, to: endDate) { result in
            switch result {
            case .success(let histories):
                let statistics = CitationStatistics(from: histories)
                completion(.success(statistics))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Export Operations
    
    /// Export citation history for a specific scholar
    func exportHistory(for scholarId: String, format: ExportFormat, completion: @escaping (Result<Data, Error>) -> Void) {
        getHistory(for: scholarId) { [weak self] result in
            switch result {
            case .success(let histories):
                do {
                    let data = try self?.formatDataForExport(histories: histories, format: format) ?? Data()
                    DispatchQueue.main.async {
                        completion(.success(data))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Export citation history for a specific scholar within a time range
    func exportHistory(for scholarId: String, in timeRange: TimeRange, format: ExportFormat, completion: @escaping (Result<Data, Error>) -> Void) {
        getHistory(for: scholarId, in: timeRange) { [weak self] result in
            switch result {
            case .success(let histories):
                do {
                    let data = try self?.formatDataForExport(histories: histories, format: format) ?? Data()
                    DispatchQueue.main.async {
                        completion(.success(data))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Export all citation history
    func exportAllHistory(format: ExportFormat, completion: @escaping (Result<Data, Error>) -> Void) {
        getAllHistory { [weak self] result in
            switch result {
            case .success(let histories):
                do {
                    let data = try self?.formatDataForExport(histories: histories, format: format) ?? Data()
                    DispatchQueue.main.async {
                        completion(.success(data))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Check if citation history exists for a scholar
    func hasHistory(for scholarId: String, completion: @escaping (Bool) -> Void) {
        getHistoryCount(for: scholarId) { count in
            completion(count > 0)
        }
    }
    
    /// Get the count of citation history entries for a scholar
    func getHistoryCount(for scholarId: String, completion: @escaping (Int) -> Void) {
        let context = coreDataManager.newBackgroundContext()
        context.perform {
            do {
                let fetchRequest: NSFetchRequest<CitationHistoryEntity> = try CitationHistoryEntity.safeFetchRequest(in: context)
                fetchRequest.predicate = NSPredicate(format: "scholarId == %@", scholarId)
                
                let count = try context.count(for: fetchRequest)
                DispatchQueue.main.async {
                    completion(count)
                }
            } catch {
                print("❌ 获取历史数据数量失败: \(error)")
                DispatchQueue.main.async {
                    completion(0)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func formatDataForExport(histories: [CitationHistory], format: ExportFormat) throws -> Data {
        switch format {
        case .csv:
            var csvContent = "Scholar ID,Citation Count,Timestamp,Source,Created At\n"
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            for history in histories {
                let timestampString = formatter.string(from: history.timestamp)
                let createdAtString = formatter.string(from: history.createdAt)
                csvContent += "\(history.scholarId),\(history.citationCount),\(timestampString),\(history.source.rawValue),\(createdAtString)\n"
            }
            
            guard let data = csvContent.data(using: .utf8) else {
                throw NSError(domain: "CitationHistoryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode CSV data"])
            }
            return data
            
        case .json:
            let exportData: [String: Any] = [
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "totalEntries": histories.count,
                "data": histories.map { history in
                    [
                        "id": history.id.uuidString,
                        "scholarId": history.scholarId,
                        "citationCount": history.citationCount,
                        "timestamp": ISO8601DateFormatter().string(from: history.timestamp),
                        "source": history.source.rawValue,
                        "createdAt": ISO8601DateFormatter().string(from: history.createdAt)
                    ]
                }
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
            return jsonData
        }
    }
    
    private func formatEmptyDataForExport(format: ExportFormat) throws -> Data {
        switch format {
        case .csv:
            let csvContent = "Scholar ID,Citation Count,Timestamp,Source,Created At\n"
            guard let data = csvContent.data(using: .utf8) else {
                throw NSError(domain: "CitationHistoryManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode CSV data"])
            }
            return data
        case .json:
            let jsonData = try JSONSerialization.data(withJSONObject: [
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "totalEntries": 0,
                "data": []
            ], options: [.prettyPrinted, .sortedKeys])
            return jsonData
        }
    }
    
    // MARK: - Suggested File Names
    
    func suggestedFileName(for scholarId: String, format: ExportFormat, timeRange: TimeRange? = nil) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        var fileName = "citations-\(scholarId)-\(dateString)"
        
        if let timeRange = timeRange, timeRange != .custom {
            fileName += "-\(timeRange.rawValue)"
        }
        
        fileName += ".\(format.fileExtension)"
        
        return fileName
    }
    
    func suggestedFileName(format: ExportFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        return "all-citations-\(dateString).\(format.fileExtension)"
    }
}