import Foundation

// MARK: - Citing Paper Model
public struct CitingPaper: Codable, Identifiable, Hashable {
    public let id: String  // 论文唯一标识
    public let title: String  // 论文标题
    public let authors: [String]  // 作者列表
    public let year: Int?  // 发表年份
    public let venue: String?  // 发表场所（期刊/会议）
    public let citationCount: Int?  // 该论文的引用数
    public let abstract: String?  // 摘要
    public let scholarUrl: String?  // Google Scholar链接
    public let pdfUrl: String?  // PDF链接
    public let citedScholarId: String  // 被引用的学者ID
    public let fetchedAt: Date  // 数据获取时间
    
    public init(
        id: String,
        title: String,
        authors: [String],
        year: Int? = nil,
        venue: String? = nil,
        citationCount: Int? = nil,
        abstract: String? = nil,
        scholarUrl: String? = nil,
        pdfUrl: String? = nil,
        citedScholarId: String,
        fetchedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.authors = authors
        self.year = year
        self.venue = venue
        self.citationCount = citationCount
        self.abstract = abstract
        self.scholarUrl = scholarUrl
        self.pdfUrl = pdfUrl
        self.citedScholarId = citedScholarId
        self.fetchedAt = fetchedAt
    }
    
    // MARK: - Helper Properties
    
    /// 作者列表的显示字符串
    public var authorsDisplay: String {
        if authors.isEmpty {
            return "Unknown Authors"
        }
        if authors.count <= 3 {
            return authors.joined(separator: ", ")
        }
        return authors.prefix(3).joined(separator: ", ") + " et al."
    }
    
    /// 年份显示字符串
    public var yearDisplay: String {
        guard let year = year else { return "N/A" }
        return String(year)
    }
    
    /// 引用数显示字符串
    public var citationDisplay: String {
        guard let count = citationCount else { return "N/A" }
        return "\(count)"
    }
    
    /// 是否有PDF链接
    public var hasPDF: Bool {
        return pdfUrl != nil && !(pdfUrl?.isEmpty ?? true)
    }
    
    /// 是否有Google Scholar链接
    public var hasScholarUrl: Bool {
        return scholarUrl != nil && !(scholarUrl?.isEmpty ?? true)
    }
}

// MARK: - Mock Data
public extension CitingPaper {
    static func mock(
        id: String = "mock_paper_1",
        title: String = "Sample Research Paper on Machine Learning",
        authors: [String] = ["John Doe", "Jane Smith", "Bob Johnson"],
        year: Int? = 2023,
        citedScholarId: String = "scholar123"
    ) -> CitingPaper {
        return CitingPaper(
            id: id,
            title: title,
            authors: authors,
            year: year,
            venue: "International Conference on Machine Learning",
            citationCount: 42,
            abstract: "This paper presents a novel approach to machine learning...",
            scholarUrl: "https://scholar.google.com/citations?view_op=view_citation&citation_for_view=\(id)",
            pdfUrl: "https://example.com/paper.pdf",
            citedScholarId: citedScholarId,
            fetchedAt: Date()
        )
    }
}
