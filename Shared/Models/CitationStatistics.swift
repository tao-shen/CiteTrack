import Foundation

// MARK: - Citation Statistics Model
public struct CitationStatistics: Codable {
    public let scholarId: String  // 学者ID
    public let totalCitingPapers: Int  // 总引用论文数
    public let uniqueCitingAuthors: Int  // 唯一引用作者数
    public let citationsByYear: [Int: Int]  // 按年份统计的引用数
    public let topCitingAuthors: [CitingAuthor]  // 最频繁引用的作者
    public let recentCitations: [CitingPaper]  // 最近的引用
    public let averageCitationsPerYear: Double  // 年均引用数
    public let lastUpdated: Date  // 最后更新时间
    
    public init(
        scholarId: String,
        totalCitingPapers: Int,
        uniqueCitingAuthors: Int,
        citationsByYear: [Int: Int],
        topCitingAuthors: [CitingAuthor],
        recentCitations: [CitingPaper],
        averageCitationsPerYear: Double,
        lastUpdated: Date = Date()
    ) {
        self.scholarId = scholarId
        self.totalCitingPapers = totalCitingPapers
        self.uniqueCitingAuthors = uniqueCitingAuthors
        self.citationsByYear = citationsByYear
        self.topCitingAuthors = topCitingAuthors
        self.recentCitations = recentCitations
        self.averageCitationsPerYear = averageCitationsPerYear
        self.lastUpdated = lastUpdated
    }
    
    // MARK: - Helper Properties
    
    /// 最早的引用年份
    public var earliestYear: Int? {
        return citationsByYear.keys.min()
    }
    
    /// 最晚的引用年份
    public var latestYear: Int? {
        return citationsByYear.keys.max()
    }
    
    /// 引用年份范围
    public var yearRange: String {
        guard let earliest = earliestYear, let latest = latestYear else {
            return "N/A"
        }
        if earliest == latest {
            return "\(earliest)"
        }
        return "\(earliest) - \(latest)"
    }
    
    /// 引用最多的年份
    public var peakYear: (year: Int, count: Int)? {
        guard let maxEntry = citationsByYear.max(by: { $0.value < $1.value }) else {
            return nil
        }
        return (year: maxEntry.key, count: maxEntry.value)
    }
    
    /// 按年份排序的引用数据（用于图表）
    public var sortedCitationsByYear: [(year: Int, count: Int)] {
        return citationsByYear
            .map { (year: $0.key, count: $0.value) }
            .sorted { $0.year < $1.year }
    }
    
    /// 最后更新时间显示
    public var lastUpdatedDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdated)
    }
}

// MARK: - Mock Data
public extension CitationStatistics {
    static func mock(scholarId: String = "scholar123") -> CitationStatistics {
        let mockAuthors = [
            CitingAuthor.mock(id: "author1", name: "Dr. Alice Johnson", citingPaperCount: 5),
            CitingAuthor.mock(id: "author2", name: "Prof. Bob Smith", citingPaperCount: 3),
            CitingAuthor.mock(id: "author3", name: "Dr. Carol White", citingPaperCount: 2)
        ]
        
        let mockPapers = [
            CitingPaper.mock(id: "paper1", title: "Recent Advances in AI", year: 2024, citedScholarId: scholarId),
            CitingPaper.mock(id: "paper2", title: "Machine Learning Applications", year: 2024, citedScholarId: scholarId),
            CitingPaper.mock(id: "paper3", title: "Deep Learning Methods", year: 2023, citedScholarId: scholarId)
        ]
        
        let citationsByYear: [Int: Int] = [
            2020: 5,
            2021: 12,
            2022: 18,
            2023: 25,
            2024: 15
        ]
        
        return CitationStatistics(
            scholarId: scholarId,
            totalCitingPapers: 75,
            uniqueCitingAuthors: 45,
            citationsByYear: citationsByYear,
            topCitingAuthors: mockAuthors,
            recentCitations: mockPapers,
            averageCitationsPerYear: 15.0,
            lastUpdated: Date()
        )
    }
}
