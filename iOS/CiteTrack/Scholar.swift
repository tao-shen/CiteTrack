import Foundation

// MARK: - Scholar Model (kept in iOS target to satisfy project references)
public struct Scholar: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var citations: Int?
    public var lastUpdated: Date?
    
    public init(id: String, name: String = "") {
        self.id = id
        self.name = name.isEmpty ? "Scholar \(id.prefix(8))" : name
        self.citations = nil
        self.lastUpdated = nil
    }
    
    // MARK: - Helper Methods
    public var displayName: String {
        return name.isEmpty ? "Scholar \(id.prefix(8))" : name
    }
    
    public var citationDisplay: String {
        guard let citations = citations else { return "Unknown" }
        return "\(citations)"
    }
    
    public var lastUpdatedDisplay: String {
        guard let lastUpdated = lastUpdated else { return "Never Updated" }
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
    static func mock(id: String = "mock123", name: String = "Test Scholar", citations: Int = 1000) -> Scholar {
        var scholar = Scholar(id: id, name: name)
        scholar.citations = citations
        scholar.lastUpdated = Date()
        return scholar
    }
}


