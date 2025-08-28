import Foundation
import SwiftUI

// MARK: - Formatting helpers
extension Int {
    var formattedNumber: String {
        if self >= 1_000_000 {
            return String(format: "%.1fm", Double(self) / 1_000_000.0)
        } else if self >= 1_000 {
            return String(format: "%.1fk", Double(self) / 1_000.0)
        } else {
            return String(self)
        }
    }
}

// MARK: - Widget Models
public enum CitationTrend {
    case up(Int)
    case down(Int)
    case unchanged
    
    public var symbol: String {
        switch self {
        case .up: return "↗"
        case .down: return "↘"
        case .unchanged: return "—"
        }
    }
    
    public var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .unchanged: return .secondary
        }
    }
    
    public var text: String {
        switch self {
        case .up(let count): return "+\(count.formattedNumber)"
        case .down(let count): return "-\(count.formattedNumber)"
        case .unchanged: return "0"
        }
    }
}

public struct WidgetScholarInfo: Codable {
    public let id: String
    public let displayName: String
    public let institution: String?
    public let citations: Int?
    public let hIndex: Int?
    public let lastUpdated: Date?
    public let weeklyGrowth: Int?
    public let monthlyGrowth: Int?
    public let quarterlyGrowth: Int?
    
    public var citationTrend: CitationTrend {
        guard let monthlyGrowthValue = monthlyGrowth else { return .unchanged }
        if monthlyGrowthValue > 0 { return .up(monthlyGrowthValue) }
        if monthlyGrowthValue < 0 { return .down(abs(monthlyGrowthValue)) }
        return .unchanged
    }
    
    public init(
        id: String,
        displayName: String,
        institution: String?,
        citations: Int?,
        hIndex: Int?,
        lastUpdated: Date?,
        weeklyGrowth: Int? = nil,
        monthlyGrowth: Int? = nil,
        quarterlyGrowth: Int? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.institution = institution
        self.citations = citations
        self.hIndex = hIndex
        self.lastUpdated = lastUpdated
        self.weeklyGrowth = weeklyGrowth
        self.monthlyGrowth = monthlyGrowth
        self.quarterlyGrowth = quarterlyGrowth
    }
}


