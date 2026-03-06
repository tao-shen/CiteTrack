import Foundation

// MARK: - Citation Context Model
/// Stores the verbatim text context of how a citing paper references one of the user's papers.
/// Data sourced from Semantic Scholar API (official, free, no scraping).
public struct CitationContext: Codable, Identifiable {
    public let id: String
    public let citingPaperTitle: String       // Title of the paper that cites the user's work
    public let citedPaperTitle: String        // Title of the user's paper that was cited
    public let contexts: [String]             // Verbatim citation sentences
    public let intents: [CitationIntent]      // Semantic Scholar's intent classification
    public let semanticScholarPaperId: String? // SS Paper ID of the user's paper
    public let fetchedAt: Date
    public let source: ContextSource

    public enum CitationIntent: String, Codable, CaseIterable, Hashable {
        case methodology = "methodology"
        case background = "background"
        case result = "result"
        case extends = "extends"
        case unknown = "unknown"

        public var displayName: String {
            switch self {
            case .methodology: return "Methodology"
            case .background: return "Background"
            case .result: return "Result"
            case .extends: return "Extension"
            case .unknown: return "General"
            }
        }

        public var icon: String {
            switch self {
            case .methodology: return "gearshape.2"
            case .background: return "book"
            case .result: return "chart.bar"
            case .extends: return "arrow.up.forward"
            case .unknown: return "quote.bubble"
            }
        }
    }

    public enum ContextSource: String, Codable {
        case semanticScholar = "semanticScholar"
        case openAlex = "openAlex"
        case unavailable = "unavailable"

        public var displayName: String {
            switch self {
            case .semanticScholar: return "Semantic Scholar"
            case .openAlex: return "OpenAlex"
            case .unavailable: return "Not Available"
            }
        }
    }

    public init(
        id: String = UUID().uuidString,
        citingPaperTitle: String,
        citedPaperTitle: String,
        contexts: [String] = [],
        intents: [CitationIntent] = [],
        semanticScholarPaperId: String? = nil,
        fetchedAt: Date = Date(),
        source: ContextSource = .semanticScholar
    ) {
        self.id = id
        self.citingPaperTitle = citingPaperTitle
        self.citedPaperTitle = citedPaperTitle
        self.contexts = contexts
        self.intents = intents
        self.semanticScholarPaperId = semanticScholarPaperId
        self.fetchedAt = fetchedAt
        self.source = source
    }
}

// MARK: - Cache Wrapper
public struct CitationContextCacheEntry: Codable {
    public let context: CitationContext?
    public let cachedAt: Date
    public let isUnavailable: Bool

    /// Cache entries expire after 7 days since citation context rarely changes
    public var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > 7 * 24 * 3600
    }

    public init(context: CitationContext?, cachedAt: Date = Date(), isUnavailable: Bool = false) {
        self.context = context
        self.cachedAt = cachedAt
        self.isUnavailable = isUnavailable
    }
}
