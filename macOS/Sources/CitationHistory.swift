import Foundation
import CoreData
import Cocoa

// MARK: - Citation History Data Model
public struct CitationHistory: Codable, Identifiable, Equatable {
    public let id: UUID
    public let scholarId: String
    public let citationCount: Int
    public let timestamp: Date
    public let source: DataSource
    public let createdAt: Date
    
    public enum DataSource: String, Codable, CaseIterable {
        case automatic = "automatic"
        case manual = "manual"
        
        public var displayName: String {
            switch self {
            case .automatic:
                return L("data_source_automatic")
            case .manual:
                return L("data_source_manual")
            }
        }
    }
    
    public init(id: UUID = UUID(), scholarId: String, citationCount: Int, timestamp: Date = Date(), source: DataSource = .automatic, createdAt: Date = Date()) {
        self.id = id
        self.scholarId = scholarId
        self.citationCount = citationCount
        self.timestamp = timestamp
        self.source = source
        self.createdAt = createdAt
    }
    
    // MARK: - Validation
    public func isValid() -> Bool {
        return !scholarId.isEmpty && citationCount >= 0
    }
    
    // MARK: - Core Data Conversion
    public func toCoreDataEntity(in context: NSManagedObjectContext) -> CitationHistoryEntity {
        let entity = CitationHistoryEntity(context: context)
        entity.id = self.id
        entity.scholarId = self.scholarId
        entity.citationCount = Int32(self.citationCount)
        entity.timestamp = self.timestamp
        entity.source = self.source.rawValue
        entity.createdAt = self.createdAt
        return entity
    }
    
    public static func fromCoreDataEntity(_ entity: CitationHistoryEntity) -> CitationHistory? {
        // Verify that required source string can be converted to enum
        guard let source = DataSource(rawValue: entity.source) else {
            print("Warning: Invalid source value '\(entity.source)' for CitationHistoryEntity")
            return nil
        }
        
        // Create CitationHistory with proper initialization
        return CitationHistory(
            id: entity.id,
            scholarId: entity.scholarId,
            citationCount: Int(entity.citationCount),
            timestamp: entity.timestamp,
            source: source,
            createdAt: entity.createdAt
        )
    }
}

// MARK: - Citation Statistics
struct CitationStatistics {
    let totalEntries: Int
    let firstEntry: Date?
    let lastEntry: Date?
    let currentCitations: Int?
    let totalChange: Int
    let averageDailyChange: Double
    let growthRate: Double
    let peakCitations: Int
    let peakDate: Date?
    
    init(from history: [CitationHistory]) {
        self.totalEntries = history.count
        
        let sortedHistory = history.sorted { $0.timestamp < $1.timestamp }
        self.firstEntry = sortedHistory.first?.timestamp
        self.lastEntry = sortedHistory.last?.timestamp
        self.currentCitations = sortedHistory.last?.citationCount
        
        if let first = sortedHistory.first, let last = sortedHistory.last {
            self.totalChange = last.citationCount - first.citationCount
            
            let daysDifference = Calendar.current.dateComponents([.day], from: first.timestamp, to: last.timestamp).day ?? 1
            self.averageDailyChange = daysDifference > 0 ? Double(totalChange) / Double(daysDifference) : 0
            
            self.growthRate = first.citationCount > 0 ? (Double(totalChange) / Double(first.citationCount)) * 100 : 0
        } else {
            self.totalChange = 0
            self.averageDailyChange = 0
            self.growthRate = 0
        }
        
        let peakEntry = history.max { $0.citationCount < $1.citationCount }
        self.peakCitations = peakEntry?.citationCount ?? 0
        self.peakDate = peakEntry?.timestamp
    }
}

// MARK: - Scholar Model Extensions
extension Scholar {
    // Historical data computed properties
    var historicalData: [CitationHistory] {
        let context = CoreDataManager.shared.viewContext
        let entities = CitationHistoryEntity.fetchHistory(for: self.id, in: context)
        return entities.compactMap { CitationHistory.fromCoreDataEntity($0) }
    }
    
    var latestChange: Int? {
        let history = historicalData.sorted { $0.timestamp < $1.timestamp }
        guard history.count >= 2 else { return nil }
        
        let latest = history.last!
        let previous = history[history.count - 2]
        return latest.citationCount - previous.citationCount
    }
    
    var growthRate: Double? {
        let history = historicalData.sorted { $0.timestamp < $1.timestamp }
        guard let first = history.first, let last = history.last, first.citationCount > 0 else { return nil }
        
        let change = last.citationCount - first.citationCount
        return (Double(change) / Double(first.citationCount)) * 100
    }
    
    var statistics: CitationStatistics {
        return CitationStatistics(from: historicalData)
    }
    
    // Get historical data for a specific time range
    func getHistoricalData(from startDate: Date, to endDate: Date) -> [CitationHistory] {
        let context = CoreDataManager.shared.viewContext
        let entities = CitationHistoryEntity.fetchHistory(for: self.id, from: startDate, to: endDate, in: context)
        return entities.compactMap { CitationHistory.fromCoreDataEntity($0) }
    }
    
    // Get the latest citation entry
    var latestHistoryEntry: CitationHistory? {
        let context = CoreDataManager.shared.viewContext
        guard let entity = CitationHistoryEntity.fetchLatestEntry(for: self.id, in: context) else { return nil }
        return CitationHistory.fromCoreDataEntity(entity)
    }
    
    // Check if there's historical data available
    var hasHistoricalData: Bool {
        return !historicalData.isEmpty
    }
    
    // Get citation trend (positive, negative, or stable)
    var citationTrend: CitationTrend {
        guard let change = latestChange else { return .stable }
        
        if change > 0 {
            return .increasing
        } else if change < 0 {
            return .decreasing
        } else {
            return .stable
        }
    }
}

// MARK: - Citation Trend Enum
enum CitationTrend: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .increasing:
            return L("trend_increasing")
        case .decreasing:
            return L("trend_decreasing")
        case .stable:
            return L("trend_stable")
        case .unknown:
            return L("trend_unknown")
        }
    }
    
    var color: NSColor {
        switch self {
        case .increasing:
            return .systemGreen
        case .decreasing:
            return .systemRed
        case .stable:
            return .systemYellow
        case .unknown:
            return .systemGray
        }
    }
    
    var symbol: String {
        switch self {
        case .increasing:
            return "↗"
        case .decreasing:
            return "↘"
        case .stable:
            return "→"
        case .unknown:
            return "?"
        }
    }
}

// MARK: - Time Range Enum
enum TimeRange: String, CaseIterable, Codable {
    case lastWeek = "lastWeek"
    case lastMonth = "lastMonth"
    case lastQuarter = "lastQuarter"
    case lastYear = "lastYear"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .lastWeek:
            return L("time_range_last_week")
        case .lastMonth:
            return L("time_range_last_month")
        case .lastQuarter:
            return L("time_range_last_quarter")
        case .lastYear:
            return L("time_range_last_year")
        case .custom:
            return L("time_range_custom")
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        return calculateDateRange()
    }
    
    private func calculateDateRange() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .lastWeek:
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return (start, now)
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        case .lastQuarter:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (start, now)
        case .lastYear:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return (start, now)
        case .custom:
            // For custom range, this should be overridden by the caller
            return (now, now)
        }
    }
}

// MARK: - Citation Change Detection
struct CitationChange {
    let scholarId: String
    let scholarName: String
    let previousCount: Int
    let newCount: Int
    let change: Int
    let timestamp: Date
    let isSignificant: Bool
    
    var changeDescription: String {
        if change > 0 {
            return L("citation_change_increase", change)
        } else if change < 0 {
            return L("citation_change_decrease", abs(change))
        } else {
            return L("citation_change_no_change")
        }
    }
    
    var percentageChange: Double? {
        guard previousCount > 0 else { return nil }
        return (Double(change) / Double(previousCount)) * 100
    }
}