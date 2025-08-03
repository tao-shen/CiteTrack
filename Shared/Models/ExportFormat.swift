import Foundation

// MARK: - Export Format
public enum ExportFormat: String, CaseIterable {
    case csv = "csv"
    case json = "json"
    
    public var displayName: String {
        switch self {
        case .csv:
            return "CSV"
        case .json:
            return "JSON"
        }
    }
    
    public var fileExtension: String {
        return self.rawValue
    }
    
    public var mimeType: String {
        switch self {
        case .csv:
            return "text/csv"
        case .json:
            return "application/json"
        }
    }
    
    public var description: String {
        switch self {
        case .csv:
            return "逗号分隔值文件"
        case .json:
            return "JSON数据文件"
        }
    }
}

// MARK: - Export Data Structure
public struct ExportData: Codable {
    public let exportDate: Date
    public let scholars: [Scholar]
    public let history: [CitationHistory]
    public let metadata: ExportMetadata
    
    public init(scholars: [Scholar], history: [CitationHistory]) {
        self.exportDate = Date()
        self.scholars = scholars
        self.history = history
        self.metadata = ExportMetadata(
            version: "1.0",
            totalScholars: scholars.count,
            totalHistoryEntries: history.count,
            dateRange: ExportMetadata.DateRange(from: history.first?.timestamp, to: history.last?.timestamp)
        )
    }
}

public struct ExportMetadata: Codable {
    public let version: String
    public let totalScholars: Int
    public let totalHistoryEntries: Int
    public let dateRange: DateRange
    
    public struct DateRange: Codable {
        public let from: Date?
        public let to: Date?
        
        public init(from: Date?, to: Date?) {
            self.from = from
            self.to = to
        }
    }
}