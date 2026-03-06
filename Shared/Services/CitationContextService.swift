import Foundation
import Combine

// MARK: - Citation Context Service
/// Business logic layer: fetches, caches, and exposes citation context data.
/// Uses Semantic Scholar as the primary source — official API, no scraping.
public class CitationContextService: ObservableObject {
    public static let shared = CitationContextService()

    /// Per-paper loading state keyed by CitingPaper.id
    @Published public var loadingStates: [String: Bool] = [:]
    /// Per-paper error messages keyed by CitingPaper.id
    @Published public var errorMessages: [String: String] = [:]

    private let cacheKeyPrefix = "CitationContext_v1_"
    private let api = SemanticScholarService.shared

    private init() {}

    // MARK: - Fetch with Cache

    /// Returns cached context immediately if fresh; otherwise fetches from Semantic Scholar.
    public func getCitationContext(
        citingPaper: CitingPaper,
        myPaperTitle: String
    ) async -> CitationContext? {
        let key = cacheKey(citingPaperId: citingPaper.id, myPaperTitle: myPaperTitle)

        // Return cached entry if still fresh
        if let cached = loadFromCache(key: key), !cached.isExpired {
            return cached.context
        }

        await setLoading(true, for: citingPaper.id)

        defer { Task { await self.setLoading(false, for: citingPaper.id) } }

        do {
            let context = try await api.findCitationContext(
                targetPaperTitle: myPaperTitle,
                citingPaperTitle: citingPaper.title
            )
            saveToCache(key: key, entry: CitationContextCacheEntry(
                context: context,
                isUnavailable: context.contexts.isEmpty
            ))
            return context
        } catch SemanticScholarError.rateLimited {
            await setError("rate_limited", for: citingPaper.id)
        } catch {
            await setError(error.localizedDescription, for: citingPaper.id)
            // Cache the failure briefly (1 hour) to avoid hammering the API
            saveToCache(key: key, entry: CitationContextCacheEntry(
                context: nil,
                cachedAt: Date().addingTimeInterval(-6 * 3600), // expire in 1h instead of 7d
                isUnavailable: true
            ))
        }
        return nil
    }

    // MARK: - Background Prefetch

    /// Silently prefetches context for up to 10 papers so the UI feels instant.
    public func prefetch(papers: [CitingPaper], myPaperTitle: String) {
        Task.detached(priority: .background) {
            for paper in papers.prefix(10) {
                let key = self.cacheKey(citingPaperId: paper.id, myPaperTitle: myPaperTitle)
                if let cached = self.loadFromCache(key: key), !cached.isExpired { continue }
                _ = await self.getCitationContext(citingPaper: paper, myPaperTitle: myPaperTitle)
                try? await Task.sleep(nanoseconds: 1_300_000_000) // 1.3 s between requests
            }
        }
    }

    // MARK: - Convenience

    public func isLoading(for citingPaperId: String) -> Bool {
        loadingStates[citingPaperId] ?? false
    }

    /// Load all cached contexts (used by CitationInsightsView)
    public func allCachedContexts() -> [CitationContext] {
        let defaults = UserDefaults.standard
        return defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(cacheKeyPrefix) }
            .compactMap { key -> CitationContext? in
                guard let data = defaults.data(forKey: key),
                      let entry = try? JSONDecoder().decode(CitationContextCacheEntry.self, from: data)
                else { return nil }
                return entry.context
            }
            .sorted { $0.fetchedAt > $1.fetchedAt }
    }

    public func clearCache() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(cacheKeyPrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: - Private Helpers

    private func cacheKey(citingPaperId: String, myPaperTitle: String) -> String {
        let slug = myPaperTitle.prefix(60)
            .components(separatedBy: .whitespacesAndNewlines)
            .joined(separator: "_")
        return "\(cacheKeyPrefix)\(citingPaperId)_\(slug)"
    }

    private func loadFromCache(key: String) -> CitationContextCacheEntry? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entry = try? JSONDecoder().decode(CitationContextCacheEntry.self, from: data)
        else { return nil }
        return entry
    }

    private func saveToCache(key: String, entry: CitationContextCacheEntry) {
        if let data = try? JSONEncoder().encode(entry) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    @MainActor
    private func setLoading(_ loading: Bool, for id: String) {
        loadingStates[id] = loading
    }

    @MainActor
    private func setError(_ message: String, for id: String) {
        errorMessages[id] = message
    }
}
