import Foundation

// MARK: - Citation Filter Model
public struct CitationFilter: Codable, Equatable {
    public var sortBy: SortOption  // 排序方式
    public var yearRange: YearRange?  // 年份范围
    public var searchKeyword: String?  // 搜索关键词
    public var authorFilter: String?  // 作者筛选
    
    public init(
        sortBy: SortOption = .yearDescending,
        yearRange: YearRange? = nil,
        searchKeyword: String? = nil,
        authorFilter: String? = nil
    ) {
        self.sortBy = sortBy
        self.yearRange = yearRange
        self.searchKeyword = searchKeyword
        self.authorFilter = authorFilter
    }
    
    // MARK: - Sort Option
    public enum SortOption: String, Codable, CaseIterable {
        case yearDescending = "year_desc"  // 年份降序
        case yearAscending = "year_asc"  // 年份升序
        case citationCountDescending = "citation_desc"  // 引用数降序
        case relevance = "relevance"  // 相关性
        case titleAscending = "title_asc"  // 标题升序
        
        public var displayName: String {
            switch self {
            case .yearDescending:
                return "sort_year_desc".localized
            case .yearAscending:
                return "sort_year_asc".localized
            case .citationCountDescending:
                return "sort_citation_desc".localized
            case .relevance:
                return "sort_relevance".localized
            case .titleAscending:
                return "sort_title_asc".localized
            }
        }
    }
    
    // MARK: - Year Range
    public struct YearRange: Codable, Equatable {
        public let start: Int
        public let end: Int
        
        public init(start: Int, end: Int) {
            self.start = min(start, end)
            self.end = max(start, end)
        }
        
        public func contains(_ year: Int) -> Bool {
            return year >= start && year <= end
        }
        
        public var displayString: String {
            if start == end {
                return "\(start)"
            }
            return "\(start) - \(end)"
        }
    }
    
    // MARK: - Filter Application
    
    /// 应用筛选到论文列表
    public func apply(to papers: [CitingPaper]) -> [CitingPaper] {
        var filtered = papers
        
        // 应用年份筛选
        if let range = yearRange {
            filtered = filtered.filter { paper in
                guard let year = paper.year else { return false }
                return range.contains(year)
            }
        }
        
        // 应用关键词搜索
        if let keyword = searchKeyword?.lowercased(), !keyword.isEmpty {
            filtered = filtered.filter { paper in
                paper.title.lowercased().contains(keyword) ||
                paper.authors.contains { $0.lowercased().contains(keyword) } ||
                (paper.abstract?.lowercased().contains(keyword) ?? false)
            }
        }
        
        // 应用作者筛选
        if let author = authorFilter?.lowercased(), !author.isEmpty {
            filtered = filtered.filter { paper in
                paper.authors.contains { $0.lowercased().contains(author) }
            }
        }
        
        // 应用排序
        filtered = sort(papers: filtered, by: sortBy)
        
        return filtered
    }
    
    /// 排序论文列表
    private func sort(papers: [CitingPaper], by option: SortOption) -> [CitingPaper] {
        switch option {
        case .yearDescending:
            return papers.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        case .yearAscending:
            return papers.sorted { ($0.year ?? 0) < ($1.year ?? 0) }
        case .citationCountDescending:
            return papers.sorted { ($0.citationCount ?? 0) > ($1.citationCount ?? 0) }
        case .relevance:
            // 相关性排序：优先考虑引用数和年份
            return papers.sorted { paper1, paper2 in
                let score1 = (paper1.citationCount ?? 0) * 10 + (paper1.year ?? 0)
                let score2 = (paper2.citationCount ?? 0) * 10 + (paper2.year ?? 0)
                return score1 > score2
            }
        case .titleAscending:
            return papers.sorted { $0.title.lowercased() < $1.title.lowercased() }
        }
    }
    
    // MARK: - Helper Properties
    
    /// 是否有活动的筛选条件
    public var hasActiveFilters: Bool {
        return yearRange != nil || 
               (searchKeyword != nil && !searchKeyword!.isEmpty) ||
               (authorFilter != nil && !authorFilter!.isEmpty)
    }
    
    /// 清除所有筛选条件
    public mutating func clearFilters() {
        yearRange = nil
        searchKeyword = nil
        authorFilter = nil
    }
}

// MARK: - Predefined Filters
public extension CitationFilter {
    /// 最近5年的论文
    static func recentYears() -> CitationFilter {
        let currentYear = Calendar.current.component(.year, from: Date())
        return CitationFilter(
            sortBy: .yearDescending,
            yearRange: YearRange(start: currentYear - 4, end: currentYear)
        )
    }
    
    /// 高引用论文（引用数降序）
    static func highCitations() -> CitationFilter {
        return CitationFilter(sortBy: .citationCountDescending)
    }
}
