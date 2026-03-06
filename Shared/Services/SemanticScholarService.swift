import Foundation

// MARK: - Semantic Scholar API Service
/// Official Semantic Scholar API client — no scraping, fully compliant.
/// Docs: https://api.semanticscholar.org/graph/v1
/// Free tier: ~100 requests per 5 minutes. Apply for a free API key to increase limits.
public class SemanticScholarService {
    public static let shared = SemanticScholarService()

    private let baseURL = "https://api.semanticscholar.org/graph/v1"
    private let session: URLSession

    /// Throttle: stay well under the free-tier rate limit of 1 req/sec
    private let minRequestInterval: TimeInterval = 1.1
    private var lastRequestTime: Date?
    private let requestQueue = DispatchQueue(label: "com.citetrack.semanticscholar", qos: .userInitiated)

    /// Optional free API key — apply at semanticscholar.org for higher rate limits
    public var apiKey: String? = nil

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20.0
        config.timeoutIntervalForResource = 40.0
        config.httpAdditionalHeaders = [
            "User-Agent": "CiteTrack-iOS/1.1 (Academic Research App; contact: citetrack@example.com)"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Rate Limiting
    private func throttle() async {
        if let last = lastRequestTime {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minRequestInterval {
                let wait = minRequestInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }

    // MARK: - Paper Search by Title
    /// Find a paper's Semantic Scholar ID by its title.
    /// Returns the best-matching result from the top 3 candidates.
    public func searchPaper(title: String) async throws -> SSPaperSearchResult? {
        await throttle()

        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "\(baseURL)/paper/search?query=\(encoded)&fields=paperId,title,year&limit=5"

        guard let url = URL(string: urlString) else { throw SemanticScholarError.invalidURL }
        let response = try await perform(request: makeRequest(url: url))

        let decoded = try JSONDecoder().decode(SSSearchResponse.self, from: response)

        // Pick the result whose title most closely matches our query
        return decoded.data.max { a, b in
            titleSimilarity(a.title, title) < titleSimilarity(b.title, title)
        }
    }

    // MARK: - Get Citations with Context
    /// Retrieve papers that cite the given SS paper ID, including verbatim citation sentences.
    public func getCitations(paperId: String, limit: Int = 200) async throws -> [SSCitingPaper] {
        await throttle()

        let urlString = "\(baseURL)/paper/\(paperId)/citations?fields=title,authors,year,contexts,intents&limit=\(limit)"
        guard let url = URL(string: urlString) else { throw SemanticScholarError.invalidURL }

        let response = try await perform(request: makeRequest(url: url))
        let decoded = try JSONDecoder().decode(SSCitationsResponse.self, from: response)
        return decoded.data
    }

    // MARK: - High-Level: Find Citation Context
    /// Given the user's paper title and a citing paper title, return the verbatim citation context.
    /// This is the main entry point used by CitationContextService.
    public func findCitationContext(
        targetPaperTitle: String,
        citingPaperTitle: String
    ) async throws -> CitationContext {
        // Step 1: Resolve user's paper title → Semantic Scholar paper ID
        guard let targetPaper = try await searchPaper(title: targetPaperTitle),
              titleSimilarity(targetPaper.title, targetPaperTitle) > 0.5 else {
            return CitationContext(
                citingPaperTitle: citingPaperTitle,
                citedPaperTitle: targetPaperTitle,
                source: .unavailable
            )
        }

        // Step 2: Fetch all papers citing the target
        let citingPapers = try await getCitations(paperId: targetPaper.paperId)

        // Step 3: Find the specific citing paper by fuzzy title match
        let matched = citingPapers.max { a, b in
            titleSimilarity(a.citingPaper.title, citingPaperTitle) < titleSimilarity(b.citingPaper.title, citingPaperTitle)
        }

        guard let match = matched,
              titleSimilarity(match.citingPaper.title, citingPaperTitle) > 0.5 else {
            return CitationContext(
                citingPaperTitle: citingPaperTitle,
                citedPaperTitle: targetPaperTitle,
                semanticScholarPaperId: targetPaper.paperId,
                source: .semanticScholar
            )
        }

        let intents: [CitationContext.CitationIntent] = Array(
            Set((match.intents ?? []).compactMap { parseIntent($0) })
        )

        return CitationContext(
            citingPaperTitle: citingPaperTitle,
            citedPaperTitle: targetPaperTitle,
            contexts: match.contexts ?? [],
            intents: intents,
            semanticScholarPaperId: targetPaper.paperId,
            source: .semanticScholar
        )
    }

    // MARK: - Helpers

    private func makeRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if let key = apiKey { req.setValue(key, forHTTPHeaderField: "x-api-key") }
        return req
    }

    private func perform(request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SemanticScholarError.invalidResponse }
        switch http.statusCode {
        case 200: return data
        case 429: throw SemanticScholarError.rateLimited
        default: throw SemanticScholarError.httpError(http.statusCode)
        }
    }

    /// Jaccard similarity on word sets — fast and good enough for paper title matching
    private func titleSimilarity(_ a: String, _ b: String) -> Double {
        let stopWords: Set<String> = ["a", "an", "the", "of", "in", "on", "for", "to", "and", "or", "is", "are"]
        func words(_ s: String) -> Set<String> {
            Set(s.lowercased()
                .components(separatedBy: .alphanumerics.inverted)
                .filter { !$0.isEmpty && !stopWords.contains($0) })
        }
        let wa = words(a), wb = words(b)
        guard !wa.isEmpty && !wb.isEmpty else { return 0 }
        let intersection = wa.intersection(wb).count
        let union = wa.union(wb).count
        return Double(intersection) / Double(union)
    }

    private func parseIntent(_ raw: String) -> CitationContext.CitationIntent? {
        switch raw.lowercased() {
        case "methodology": return .methodology
        case "background": return .background
        case "result": return .result
        case "extends": return .extends
        default: return .unknown
        }
    }
}

// MARK: - Response Models

public struct SSSearchResponse: Codable {
    public let data: [SSPaperSearchResult]
}

public struct SSPaperSearchResult: Codable {
    public let paperId: String
    public let title: String
    public let year: Int?
}

public struct SSCitationsResponse: Codable {
    public let data: [SSCitingPaper]
}

public struct SSCitingPaper: Codable {
    public let citingPaper: SSCitingPaperInfo
    public let contexts: [String]?
    public let intents: [String]?
}

public struct SSCitingPaperInfo: Codable {
    public let paperId: String
    public let title: String
    public let year: Int?
    public let authors: [SSAuthor]?
}

public struct SSAuthor: Codable {
    public let authorId: String?
    public let name: String
}

// MARK: - Errors

public enum SemanticScholarError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rateLimited
    case httpError(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .rateLimited: return "Rate limited. Please wait a moment and try again."
        case .httpError(let code): return "HTTP \(code) error from Semantic Scholar"
        }
    }
}
