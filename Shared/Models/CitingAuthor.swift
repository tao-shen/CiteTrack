import Foundation

// MARK: - Citing Author Model
public struct CitingAuthor: Codable, Identifiable, Hashable {
    public let id: String  // 作者的Scholar ID
    public let name: String  // 作者姓名
    public let affiliation: String?  // 所属机构
    public let interests: [String]?  // 研究兴趣
    public let citationCount: Int?  // 作者总引用数
    public let hIndex: Int?  // h-index
    public let citingPaperCount: Int  // 引用我的论文数量
    public let scholarUrl: String  // Google Scholar个人主页
    
    public init(
        id: String,
        name: String,
        affiliation: String? = nil,
        interests: [String]? = nil,
        citationCount: Int? = nil,
        hIndex: Int? = nil,
        citingPaperCount: Int,
        scholarUrl: String
    ) {
        self.id = id
        self.name = name
        self.affiliation = affiliation
        self.interests = interests
        self.citationCount = citationCount
        self.hIndex = hIndex
        self.citingPaperCount = citingPaperCount
        self.scholarUrl = scholarUrl
    }
    
    // MARK: - Helper Properties
    
    /// 机构显示字符串
    public var affiliationDisplay: String {
        return affiliation ?? "Unknown Affiliation"
    }
    
    /// 研究兴趣显示字符串
    public var interestsDisplay: String {
        guard let interests = interests, !interests.isEmpty else {
            return "No interests listed"
        }
        return interests.joined(separator: ", ")
    }
    
    /// 引用数显示字符串
    public var citationDisplay: String {
        guard let count = citationCount else { return "N/A" }
        return "\(count)"
    }
    
    /// h-index显示字符串
    public var hIndexDisplay: String {
        guard let h = hIndex else { return "N/A" }
        return "\(h)"
    }
    
    /// 引用我的论文数量显示
    public var citingPaperCountDisplay: String {
        return "\(citingPaperCount) paper\(citingPaperCount == 1 ? "" : "s")"
    }
}

// MARK: - Mock Data
public extension CitingAuthor {
    static func mock(
        id: String = "mock_author_1",
        name: String = "Dr. Alice Johnson",
        citingPaperCount: Int = 5
    ) -> CitingAuthor {
        return CitingAuthor(
            id: id,
            name: name,
            affiliation: "Stanford University",
            interests: ["Machine Learning", "Natural Language Processing", "Computer Vision"],
            citationCount: 15000,
            hIndex: 45,
            citingPaperCount: citingPaperCount,
            scholarUrl: "https://scholar.google.com/citations?user=\(id)"
        )
    }
}
