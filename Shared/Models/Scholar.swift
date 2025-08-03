import Foundation

// MARK: - Scholar Model
public struct Scholar: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var citations: Int?
    public var lastUpdated: Date?
    
    public init(id: String, name: String = "") {
        self.id = id
        self.name = name.isEmpty ? "学者 \(id.prefix(8))" : name
        self.citations = nil
        self.lastUpdated = nil
    }
    
    // MARK: - Helper Methods
    
    public var displayName: String {
        return name.isEmpty ? "学者 \(id.prefix(8))" : name
    }
    
    public var citationDisplay: String {
        guard let citations = citations else { return "未知" }
        return "\(citations)"
    }
    
    public var lastUpdatedDisplay: String {
        guard let lastUpdated = lastUpdated else { return "从未更新" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdated)
    }
    
    public var isDataAvailable: Bool {
        return citations != nil
    }
}

// MARK: - Scholar Extensions
public extension Scholar {
    static func mock(id: String = "mock123", name: String = "测试学者", citations: Int = 1000) -> Scholar {
        var scholar = Scholar(id: id, name: name)
        scholar.citations = citations
        scholar.lastUpdated = Date()
        return scholar
    }
}