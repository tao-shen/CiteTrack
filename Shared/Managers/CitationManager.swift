import Foundation
import Combine

// MARK: - Citation Manager
public class CitationManager: ObservableObject {
    // 使用 nonisolated(unsafe) 来允许从非主线程访问 shared
    // 注意：这要求所有对 shared 的访问都确保在主线程上（SwiftUI 的 @StateObject 会保证这一点）
    nonisolated(unsafe) public static let shared = CitationManager()
    
    // Published properties
    @Published public var citingPapers: [String: [CitingPaper]] = [:]  // scholarId -> papers
    @Published public var citingAuthors: [String: [CitingAuthor]] = [:]  // scholarId -> authors
    @Published public var statistics: [String: CitationStatistics] = [:]  // scholarId -> stats
    @Published public var scholarPublications: [String: [PublicationInfo]] = [:]  // scholarId -> publications
    @Published public var publicationChanges: [String: CitationCacheService.PublicationChanges] = [:]  // scholarId -> changes
    @Published public var isLoading: Bool = false
    @Published public var isLoadingMore: Bool = false  // 加载更多时的状态
    @Published public var hasMorePublications: [String: Bool] = [:]  // scholarId -> 是否还有更多论文
    @Published public var error: CitationFetchService.CitationError?
    
    // Services
    private let fetchService: CitationFetchService
    private let cacheService: CitationCacheService
    private let exportService: CitationExportService
    
    // 新增：获取协调器（延迟初始化，确保在主线程上访问）
    public let fetchCoordinator: CitationFetchCoordinator
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.fetchService = CitationFetchService.shared
        self.cacheService = CitationCacheService.shared
        self.exportService = CitationExportService.shared
        // 延迟初始化 fetchCoordinator，确保在主线程上访问
        // 由于 SwiftUI 的 @StateObject 会在主线程上创建实例，这里使用 assumeIsolated 是安全的
        self.fetchCoordinator = MainActor.assumeIsolated {
            CitationFetchCoordinator.shared
        }
    }
    
    // MARK: - Fetch Citing Papers
    
    /// 获取学者的论文列表（使用新的批量预取策略）
    public func fetchScholarPublications(for scholarId: String, sortBy: String? = nil, forceRefresh: Bool = false) {
        logInfo("Fetching scholar publications for: \(scholarId), sortBy: \(sortBy ?? "default"), forceRefresh: \(forceRefresh)")
        
        isLoading = true
        error = nil
        
        // 计算起始索引
        let startIndex = forceRefresh ? 0 : (scholarPublications[scholarId]?.count ?? 0)
        let effectiveSortBy = sortBy ?? "total"
        
        // 先检查缓存（即使 forceRefresh，也先显示缓存，然后后台刷新）
        if let cachedPublications = cacheService.getCachedScholarPublicationsList(for: scholarId, sortBy: effectiveSortBy, startIndex: startIndex) {
            logInfo("💾 Using cached publications for: \(scholarId), sortBy: \(effectiveSortBy), startIndex: \(startIndex)")
            
            // 转换为 PublicationInfo
            let pubInfos = cachedPublications.map { pub in
                PublicationInfo(
                    id: pub.id,
                    title: pub.title,
                    clusterId: pub.clusterId,
                    citationCount: pub.citationCount,
                    year: pub.year
                )
            }
            
            // 判断是否还有更多论文
            let hasMore = cachedPublications.count >= 100
            self.hasMorePublications[scholarId] = hasMore
            
            if startIndex == 0 {
                // 首次加载：替换数据
                self.scholarPublications[scholarId] = pubInfos
            } else {
                // 加载更多：追加数据
                var existing = self.scholarPublications[scholarId] ?? []
                existing.append(contentsOf: pubInfos)
                self.scholarPublications[scholarId] = existing
            }
            
            self.updatePublicationStatistics(for: scholarId, publications: self.scholarPublications[scholarId] ?? [])
            self.isLoading = false
            
            // 如果是首次加载，启动后台批量预取任务（只预取当前排序方式的其他页面，不预取其他排序方式）
            if startIndex == 0 {
                Task {
                    // 等待一小段时间，确保第一页数据已经写入缓存
                    try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5秒
                    
                    // 后台预取当前排序方式的其他页面（不包括第一页，因为已经显示了）
                    // 注意：不预取其他排序方式，只在用户实际切换排序时才获取
                    // 注意：addTask 会自动跳过已缓存的任务，所以第一页不会重复获取
                    await MainActor.run {
                        fetchCoordinator.prefetchOtherPages(scholarId: scholarId, sortBy: effectiveSortBy, pages: 3)
                    }
                }
            }
            
            return
        }
        
        // 缓存未命中，使用批量预取
        logInfo("🚀 Cache miss, starting batch prefetch for: \(scholarId), sortBy: \(effectiveSortBy), startIndex: \(startIndex)")
        
        // 如果是强制刷新，清空现有数据
        if forceRefresh {
            scholarPublications[scholarId] = []
            hasMorePublications[scholarId] = true
        }
        
        Task { @MainActor in
            // 只获取当前选择的排序方式的第一页，立即显示
            await fetchCoordinator.fetchScholarPublicationsWithPrefetch(scholarId: scholarId, sortBy: effectiveSortBy, priority: .high, onlyFirstPage: true)
            
            // 第一页完成后，从缓存加载数据到UI
            if let cachedPublications = cacheService.getCachedScholarPublicationsList(for: scholarId, sortBy: effectiveSortBy, startIndex: startIndex) {
                logInfo("✅ Loaded \(cachedPublications.count) publications from cache after first page fetch")
                
                let pubInfos = cachedPublications.map { pub in
                    PublicationInfo(
                        id: pub.id,
                        title: pub.title,
                        clusterId: pub.clusterId,
                        citationCount: pub.citationCount,
                        year: pub.year
                    )
                }
                
                let hasMore = cachedPublications.count >= 100
                self.hasMorePublications[scholarId] = hasMore
                
                if startIndex == 0 {
                    self.scholarPublications[scholarId] = pubInfos
                } else {
                    var existing = self.scholarPublications[scholarId] ?? []
                    existing.append(contentsOf: pubInfos)
                    self.scholarPublications[scholarId] = existing
                }
                
                self.updatePublicationStatistics(for: scholarId, publications: self.scholarPublications[scholarId] ?? [])
            } else {
                logInfo("⚠️ No cached publications found after first page fetch for: \(scholarId), sortBy: \(effectiveSortBy), startIndex: \(startIndex)")
            }
            
            self.isLoading = false
        }
    }
    
    /// 旧的获取方法（保留作为后备）
    private func fetchScholarPublicationsLegacy(for scholarId: String, sortBy: String? = nil, forceRefresh: Bool = false) {
        let startIndex = 0
        fetchService.fetchScholarPublications(for: scholarId, sortBy: sortBy, startIndex: startIndex, forceRefresh: forceRefresh) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let publications):
                    self.logSuccess("Fetched \(publications.count) publications starting from index \(startIndex)")
                    
                    // 转换为 PublicationInfo
                    let pubInfos = publications.map { pub in
                        PublicationInfo(
                            id: pub.id,
                            title: pub.title,
                            clusterId: pub.clusterId,
                            citationCount: pub.citationCount,
                            year: pub.year
                        )
                    }
                    
                    // 转换为 PublicationSnapshot 用于缓存和对比
                    let snapshots = publications.map { pub in
                        CitationCacheService.PublicationSnapshot(
                            title: pub.title,
                            clusterId: pub.clusterId,
                            citationCount: pub.citationCount,
                            year: pub.year
                        )
                    }
                    
                    // 判断是否还有更多论文（如果返回的论文数少于100，说明没有更多了）
                    let hasMore = publications.count >= 100
                    self.hasMorePublications[scholarId] = hasMore
                    
                    // 缓存分页数据
                    self.cacheService.cacheScholarPublicationsList(publications, for: scholarId, sortBy: sortBy, startIndex: startIndex)
                    
                    if forceRefresh || startIndex == 0 {
                        // 首次加载或强制刷新：替换数据
                        // 对比变化（只在首次加载时对比）
                        if let cachedPublications = self.cacheService.getCachedPublications(for: scholarId) {
                            let changes = self.cacheService.comparePublications(old: cachedPublications, new: snapshots)
                            if changes.hasChanges {
                                self.logSuccess("Found \(changes.totalNewCitations) new citations across \(changes.increased.count) publications")
                                self.publicationChanges[scholarId] = changes
                            }
                        }
                        
                        // 缓存新数据（用于变化对比）
                        self.cacheService.cachePublications(snapshots, for: scholarId)
                        
                        self.scholarPublications[scholarId] = pubInfos
                    } else {
                        // 加载更多：追加数据
                        var existing = self.scholarPublications[scholarId] ?? []
                        existing.append(contentsOf: pubInfos)
                        self.scholarPublications[scholarId] = existing
                    }
                    
                    self.updatePublicationStatistics(for: scholarId, publications: self.scholarPublications[scholarId] ?? [])
                    
                case .failure(let error):
                    self.logError("Failed to fetch publications", error: error)
                    self.error = error
                    // 如果加载失败，假设没有更多了
                    self.hasMorePublications[scholarId] = false
                }
            }
        }
    }
    
    /// 加载更多论文（分页加载）
    public func loadMorePublications(for scholarId: String, sortBy: String? = nil) {
        // 如果正在加载或没有更多，则不加载
        guard !isLoadingMore,
              hasMorePublications[scholarId] != false else {
            return
        }
        
        logInfo("Loading more publications for: \(scholarId)")
        isLoadingMore = true
        
        let startIndex = scholarPublications[scholarId]?.count ?? 0
        
        // 先检查缓存
        if let cachedPublications = cacheService.getCachedScholarPublicationsList(for: scholarId, sortBy: sortBy, startIndex: startIndex) {
            logInfo("Using cached publications for load more: \(scholarId), startIndex: \(startIndex)")
            
            // 转换为 PublicationInfo
            let pubInfos = cachedPublications.map { pub in
                PublicationInfo(
                    id: pub.id,
                    title: pub.title,
                    clusterId: pub.clusterId,
                    citationCount: pub.citationCount,
                    year: pub.year
                )
            }
            
            // 判断是否还有更多论文
            let hasMore = cachedPublications.count >= 100
            self.hasMorePublications[scholarId] = hasMore
            
            // 追加数据
            var existing = self.scholarPublications[scholarId] ?? []
            existing.append(contentsOf: pubInfos)
            self.scholarPublications[scholarId] = existing
            
            self.updatePublicationStatistics(for: scholarId, publications: self.scholarPublications[scholarId] ?? [])
            self.isLoadingMore = false
            
            // 在后台更新数据（静默刷新）
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.fetchService.fetchScholarPublications(for: scholarId, sortBy: sortBy, startIndex: startIndex, forceRefresh: false) { result in
                    guard let self = self else { return }
                    // 静默更新缓存
                    if case .success(let publications) = result {
                        self.cacheService.cacheScholarPublicationsList(publications, for: scholarId, sortBy: sortBy, startIndex: startIndex)
                    }
                }
            }
            return
        }
        
        fetchService.fetchScholarPublications(for: scholarId, sortBy: sortBy, startIndex: startIndex, forceRefresh: false) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingMore = false
                
                switch result {
                case .success(let publications):
                    // 缓存分页数据
                    self.cacheService.cacheScholarPublicationsList(publications, for: scholarId, sortBy: sortBy, startIndex: startIndex)
                    
                    // 转换为 PublicationInfo
                    let pubInfos = publications.map { pub in
                        PublicationInfo(
                            id: pub.id,
                            title: pub.title,
                            clusterId: pub.clusterId,
                            citationCount: pub.citationCount,
                            year: pub.year
                        )
                    }
                    
                    // 判断是否还有更多论文
                    let hasMore = publications.count >= 100
                    self.hasMorePublications[scholarId] = hasMore
                    
                    // 追加数据
                    var existing = self.scholarPublications[scholarId] ?? []
                    existing.append(contentsOf: pubInfos)
                    self.scholarPublications[scholarId] = existing
                    
                    self.updatePublicationStatistics(for: scholarId, publications: self.scholarPublications[scholarId] ?? [])
                    
                case .failure(let error):
                    self.logError("Failed to load more publications", error: error)
                    self.error = error
                    self.hasMorePublications[scholarId] = false
                }
            }
        }
    }
    
    /// 获取引用论文（优先使用缓存）- 已弃用，改用fetchScholarPublications
    @available(*, deprecated, message: "Use fetchScholarPublications instead due to Google Scholar restrictions")
    public func fetchCitingPapers(for scholarId: String, forceRefresh: Bool = false) {
        logInfo("fetchCitingPapers is deprecated, using fetchScholarPublications instead")
        fetchScholarPublications(for: scholarId, forceRefresh: forceRefresh)
    }
    
    // MARK: - Fetch Citing Authors
    
    /// 获取引用作者
    public func fetchCitingAuthors(for scholarId: String, forceRefresh: Bool = false) {
        logInfo("Fetching citing authors for scholar: \(scholarId)")
        
        // 如果不强制刷新且有缓存，使用缓存
        if !forceRefresh {
            if let cachedAuthors = cacheService.getCachedCitingAuthors(for: scholarId) {
                logInfo("Using cached authors (\(cachedAuthors.count) authors)")
                DispatchQueue.main.async {
                    self.citingAuthors[scholarId] = cachedAuthors
                }
                return
            }
        }
        
        // 从网络获取
        isLoading = true
        error = nil
        
        fetchService.fetchCitingAuthors(for: scholarId) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let authors):
                    self.logSuccess("Fetched \(authors.count) citing authors")
                    self.citingAuthors[scholarId] = authors
                    
                    // 缓存数据
                    self.cacheService.cacheCitingAuthors(authors, for: scholarId)
                    
                case .failure(let error):
                    self.logError("Failed to fetch citing authors", error: error)
                    self.error = error
                    
                    // 尝试使用缓存数据
                    if let cachedAuthors = self.cacheService.getCachedCitingAuthors(for: scholarId) {
                        self.logInfo("Using cached authors as fallback")
                        self.citingAuthors[scholarId] = cachedAuthors
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    /// 计算引用统计
    public func calculateStatistics(for scholarId: String) -> CitationStatistics {
        let papers = citingPapers[scholarId] ?? []
        let authors = citingAuthors[scholarId] ?? []
        
        // 按年份统计引用数
        var citationsByYear: [Int: Int] = [:]
        for paper in papers {
            if let year = paper.year {
                citationsByYear[year, default: 0] += 1
            }
        }
        
        // 获取最频繁引用的作者（前10位）
        let topAuthors = Array(authors.prefix(10))
        
        // 获取最近的引用（按年份排序，取前10篇）
        let recentCitations = papers
            .sorted { ($0.year ?? 0) > ($1.year ?? 0) }
            .prefix(10)
            .map { $0 }
        
        // 计算年均引用数
        let years = citationsByYear.keys.sorted()
        let averageCitationsPerYear: Double
        if years.count > 1, let earliest = years.first, let latest = years.last {
            let yearSpan = latest - earliest + 1
            averageCitationsPerYear = Double(papers.count) / Double(yearSpan)
        } else {
            averageCitationsPerYear = Double(papers.count)
        }
        
        let stats = CitationStatistics(
            scholarId: scholarId,
            totalCitingPapers: papers.count,
            uniqueCitingAuthors: authors.count,
            citationsByYear: citationsByYear,
            topCitingAuthors: topAuthors,
            recentCitations: Array(recentCitations),
            averageCitationsPerYear: averageCitationsPerYear,
            lastUpdated: Date()
        )
        
        DispatchQueue.main.async {
            self.statistics[scholarId] = stats
        }
        
        return stats
    }
    
    /// 更新统计数据
    private func updateStatistics(for scholarId: String) {
        _ = calculateStatistics(for: scholarId)
    }
    
    /// 根据论文列表更新统计数据
    private func updatePublicationStatistics(for scholarId: String, publications: [PublicationInfo]) {
        let totalCitations = publications.compactMap { $0.citationCount }.reduce(0, +)
        _ = publications.filter { ($0.citationCount ?? 0) > 0 }  // papersWithCitations
        
        // 按年份统计引用数
        var citationsByYear: [Int: Int] = [:]
        for pub in publications {
            if let year = pub.year, let count = pub.citationCount {
                citationsByYear[year, default: 0] += count
            }
        }
        
        // 计算年均引用数
        let years = citationsByYear.keys.sorted()
        let averageCitationsPerYear: Double
        if years.count > 1, let earliest = years.first, let latest = years.last {
            let yearSpan = latest - earliest + 1
            averageCitationsPerYear = Double(totalCitations) / Double(yearSpan)
        } else {
            averageCitationsPerYear = Double(totalCitations)
        }
        
        // 创建统计对象
        let stats = CitationStatistics(
            scholarId: scholarId,
            totalCitingPapers: totalCitations,
            uniqueCitingAuthors: 0, // 无法获取
            citationsByYear: citationsByYear,
            topCitingAuthors: [],
            recentCitations: [],
            averageCitationsPerYear: averageCitationsPerYear,
            lastUpdated: Date()
        )
        
        DispatchQueue.main.async {
            self.statistics[scholarId] = stats
        }
        
        logSuccess("Updated statistics: \(totalCitations) total citations from \(publications.count) publications")
    }
}

// MARK: - Publication Info (for iOS views)
public struct PublicationInfo: Identifiable, Codable {
    public let id: String
    public let title: String
    public let clusterId: String?
    public let citationCount: Int?
    public let year: Int?
    
    public init(id: String, title: String, clusterId: String?, citationCount: Int?, year: Int?) {
        self.id = id
        self.title = title
        self.clusterId = clusterId
        self.citationCount = citationCount
        self.year = year
    }
}

extension CitationManager {
    // MARK: - Filter
    
    /// 应用筛选
    public func applyFilter(_ filter: CitationFilter, to papers: [CitingPaper]) -> [CitingPaper] {
        return filter.apply(to: papers)
    }
    
    /// 获取筛选后的论文
    public func getFilteredPapers(for scholarId: String, filter: CitationFilter) -> [CitingPaper] {
        let papers = citingPapers[scholarId] ?? []
        return applyFilter(filter, to: papers)
    }
    
    // MARK: - Export
    
    /// 导出数据
    public func exportData(papers: [CitingPaper], format: CitationExportService.ExportFormat) -> Data? {
        switch format {
        case .csv:
            return exportService.exportToCSV(papers: papers)
        case .json:
            return exportService.exportToJSON(papers: papers)
        case .bibtex:
            return exportService.exportToBibTeX(papers: papers)
        }
    }
    
    /// 导出数据并生成文件名
    public func exportData(
        for scholarId: String,
        papers: [CitingPaper],
        format: CitationExportService.ExportFormat
    ) -> ExportResult? {
        guard let data = exportData(papers: papers, format: format) else {
            return nil
        }
        
        let fileName = exportService.generateFileName(
            for: scholarId,
            format: format,
            paperCount: papers.count
        )
        
        return ExportResult(data: data, fileName: fileName, format: format)
    }
    
    // MARK: - Cache Management
    
    /// 清除缓存
    public func clearCache(for scholarId: String) {
        cacheService.clearCache(for: scholarId)
        
        DispatchQueue.main.async {
            self.citingPapers.removeValue(forKey: scholarId)
            self.citingAuthors.removeValue(forKey: scholarId)
            self.statistics.removeValue(forKey: scholarId)
        }
        
        logInfo("Cleared cache for scholar: \(scholarId)")
    }
    
    /// 清除所有缓存
    public func clearAllCache() {
        cacheService.clearAllCache()
        
        DispatchQueue.main.async {
            self.citingPapers.removeAll()
            self.citingAuthors.removeAll()
            self.statistics.removeAll()
        }
        
        logInfo("Cleared all cache")
    }
    
    /// 获取缓存统计
    public func getCacheStatistics() -> (scholars: Int, papers: Int, authors: Int) {
        return cacheService.getCacheStatistics()
    }
    
    /// 检查缓存是否过期
    public func isCacheExpired(for scholarId: String) -> Bool {
        return cacheService.isCacheExpired(for: scholarId)
    }
    
    /// 获取缓存最后更新时间
    public func getCacheLastUpdated(for scholarId: String) -> Date? {
        return cacheService.getCacheLastUpdated(for: scholarId)
    }
    
    // MARK: - Refresh All Data
    
    /// 刷新所有数据
    public func refreshAllData(for scholarId: String) {
        logInfo("Refreshing all data for scholar: \(scholarId)")
        
        // 清除缓存
        clearCache(for: scholarId)
        
        // 重新获取论文列表（使用新方法）
        fetchScholarPublications(for: scholarId, forceRefresh: true)
    }
    
    // MARK: - Helper Methods
    
    /// 获取论文数量
    public func getPaperCount(for scholarId: String) -> Int {
        return citingPapers[scholarId]?.count ?? 0
    }
    
    /// 获取作者数量
    public func getAuthorCount(for scholarId: String) -> Int {
        return citingAuthors[scholarId]?.count ?? 0
    }
    
    /// 检查是否有数据
    public func hasData(for scholarId: String) -> Bool {
        return getPaperCount(for: scholarId) > 0
    }
    
    /// 检查是否正在加载
    public func isLoadingData(for scholarId: String) -> Bool {
        return isLoading
    }
    
    // MARK: - Logging
    
    private func logInfo(_ message: String) {
        print("ℹ️ [CitationManager] \(message)")
    }
    
    private func logSuccess(_ message: String) {
        print("✅ [CitationManager] \(message)")
    }
    
    private func logWarning(_ message: String) {
        print("⚠️ [CitationManager] \(message)")
    }
    
    private func logError(_ message: String, error: Error? = nil) {
        if let error = error {
            print("❌ [CitationManager] \(message): \(error.localizedDescription)")
        } else {
            print("❌ [CitationManager] \(message)")
        }
    }
}

// MARK: - Combine Extensions
public extension CitationManager {
    /// 使用Combine获取引用论文（已弃用，使用fetchScholarPublicationsPublisher）
    @available(*, deprecated, message: "Use fetchScholarPublicationsPublisher instead")
    func fetchCitingPapersPublisher(for scholarId: String, forceRefresh: Bool = false) -> AnyPublisher<[CitingPaper], Never> {
        return Future { promise in
            // 使用新的方法获取论文
            self.fetchScholarPublications(for: scholarId, forceRefresh: forceRefresh)
            
            // 等待数据更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 返回空数组，因为新方法不填充citingPapers
                promise(.success([]))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 使用Combine获取引用作者
    func fetchCitingAuthorsPublisher(for scholarId: String, forceRefresh: Bool = false) -> AnyPublisher<[CitingAuthor], Never> {
        return Future { promise in
            self.fetchCitingAuthors(for: scholarId, forceRefresh: forceRefresh)
            
            // 等待数据更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let authors = self.citingAuthors[scholarId] ?? []
                promise(.success(authors))
            }
        }
        .eraseToAnyPublisher()
    }
}
