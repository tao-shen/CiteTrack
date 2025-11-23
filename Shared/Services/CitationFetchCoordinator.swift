import Foundation
import Combine

/// 获取任务的优先级
public enum FetchPriority: Int, Comparable {
    case high = 3      // 用户主动请求
    case medium = 2    // 预取可能需要的数据
    case low = 1       // 后台批量获取
    
    public static func < (lhs: FetchPriority, rhs: FetchPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Google Scholar 页面类型（与页面种类对应）
public enum GoogleScholarPageType {
    case scholarProfile(scholarId: String, sortBy: String?, startIndex: Int)  // 学者主页
    case citedBy(clusterId: String, sortByDate: Bool, startIndex: Int)          // 引用页面
    case paperDetail(paperId: String)                                           // 论文详情页（保留）
    case authorSearch(authorName: String)                                       // 作者搜索页（保留）
    
    /// 页面标识符（用于缓存和去重）
    var identifier: String {
        switch self {
        case .scholarProfile(let scholarId, let sortBy, let startIndex):
            let sort = sortBy ?? "total"
            return "profile_\(scholarId)_\(sort)_\(startIndex)"
        case .citedBy(let clusterId, let sortByDate, let startIndex):
            return "citedby_\(clusterId)_\(sortByDate)_\(startIndex)"
        case .paperDetail(let paperId):
            return "paper_\(paperId)"
        case .authorSearch(let authorName):
            return "author_\(authorName)"
        }
    }
    
    /// 页面URL（用于访问）
    var url: URL? {
        switch self {
        case .scholarProfile(let scholarId, let sortBy, let startIndex):
            var urlString = "https://scholar.google.com/citations?user=\(scholarId)&hl=en&cstart=\(startIndex)&pagesize=100"
            if let sortBy = sortBy {
                urlString += "&sortby=\(sortBy)"
            }
            return URL(string: urlString)
            
        case .citedBy(let clusterId, let sortByDate, let startIndex):
            var urlString = "https://scholar.google.com/scholar?hl=en&cites=\(clusterId)"
            if sortByDate {
                urlString += "&scisbd=1"
            }
            if startIndex > 0 {
                urlString += "&start=\(startIndex)"
            }
            return URL(string: urlString)
            
        case .paperDetail(let paperId):
            return URL(string: "https://scholar.google.com/scholar?hl=en&cluster=\(paperId)")
            
        case .authorSearch(let authorName):
            let encodedName = authorName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? authorName
            return URL(string: "https://scholar.google.com/citations?hl=en&view_op=search_authors&mauthors=\(encodedName)")
        }
    }
    
    /// 从页面提取的内容类型
    var extractedContentType: String {
        switch self {
        case .scholarProfile:
            return "ScholarInfo + Publications"
        case .citedBy:
            return "CitingPapers"
        case .paperDetail:
            return "PaperDetails"
        case .authorSearch:
            return "AuthorInfo"
        }
    }
}

/// 获取任务类型（基于页面类型）
enum FetchTaskType: Hashable {
    case scholarProfile(scholarId: String, sortBy: String, startIndex: Int)  // 学者主页
    case citedBy(clusterId: String, sortByDate: Bool, startIndex: Int)      // 引用页面
    
    /// 转换为页面类型
    var pageType: GoogleScholarPageType {
        switch self {
        case .scholarProfile(let scholarId, let sortBy, let startIndex):
            return .scholarProfile(scholarId: scholarId, sortBy: sortBy, startIndex: startIndex)
        case .citedBy(let clusterId, let sortByDate, let startIndex):
            return .citedBy(clusterId: clusterId, sortByDate: sortByDate, startIndex: startIndex)
        }
    }
    
    var identifier: String {
        return pageType.identifier
    }
}

/// 获取任务
struct FetchTask: Comparable {
    let type: FetchTaskType
    let priority: FetchPriority
    let createdAt: Date
    
    static func < (lhs: FetchTask, rhs: FetchTask) -> Bool {
        // 首先按优先级排序
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        // 相同优先级按创建时间排序（先创建的先执行）
        return lhs.createdAt < rhs.createdAt
    }
    
    static func == (lhs: FetchTask, rhs: FetchTask) -> Bool {
        return lhs.type == rhs.type
    }
}

/// 获取协调器：管理所有数据获取任务，实现批量预取和智能缓存
@MainActor
public class CitationFetchCoordinator: ObservableObject {
    public static let shared = CitationFetchCoordinator()
    
    // MARK: - Published Properties
    
    @Published public var isProcessing = false
    @Published public var queueSize = 0
    @Published public var completedTasks = 0
    @Published public var failedTasks = 0
    @Published public var totalFetchCount = 0  // 总fetch次数统计
    
    // MARK: - Private Properties
    
    private var taskQueue: [FetchTask] = []
    private var processedTasks: Set<String> = []  // 已处理的任务标识符
    private var isProcessingQueue = false
    private var fetchCountByPageType: [String: Int] = [:]  // 按页面类型统计fetch次数
    
    private let fetchService = CitationFetchService.shared
    private let cacheService = CitationCacheService.shared
    
    // 配置参数
    private let minDelayBetweenRequests: TimeInterval = 2.0  // 最小请求间隔（减少延迟）
    private let maxDelayBetweenRequests: TimeInterval = 3.0  // 最大请求间隔（减少延迟）
    
    // 第一页任务不需要延迟（立即处理，快速响应）
    private let firstPageDelay: TimeInterval = 0.0  // 第一页任务无延迟
    private let prefetchPagesCount = 3  // 预取的页数
    
    private init() {
        print("📋 [FetchCoordinator] Initialized")
    }
    
    // MARK: - Public API
    
    // MARK: - 按页面类型组织的 Fetch 方法
    
    /// Fetch 学者主页 (Scholar Profile Page)
    /// 页面类型: scholarProfile
    /// 提取内容: 学者基本信息 + 论文列表（尽可能多地获取）
    /// 缓存管理: 
    ///   - 学者信息 → UnifiedCacheManager.scholarBasicInfo
    ///   - 论文列表 → UnifiedCacheManager.scholarPublications + CitationCacheService
    ///   - 自动合并本地已有数据
    @discardableResult
    public func fetchScholarProfilePage(
        scholarId: String,
        sortBy: String = "total",
        startIndex: Int = 0,
        priority: FetchPriority = .high
    ) async -> Bool {
        print("📄 [FetchCoordinator] Fetch Scholar Profile Page: \(scholarId), sortBy: \(sortBy), startIndex: \(startIndex)")
        
        addTask(.scholarProfile(scholarId: scholarId, sortBy: sortBy, startIndex: startIndex), priority: priority)
        
        // 如果是第一页，立即处理（包含学者信息）
        if startIndex == 0 {
            await processQueueUntilFirstPageComplete()
            return true
        }
        
        // 其他页面后台处理
        await processQueue()
        return true
    }
    
    /// Fetch 引用页面 (Cited By Page)
    /// 页面类型: citedBy
    /// 提取内容: 引用论文列表（尽可能多地获取）
    /// 缓存管理:
    ///   - 引用论文 → CitationCacheService.citingPapersCache
    ///   - 自动合并本地已有数据
    @discardableResult
    public func fetchCitedByPage(
        clusterId: String,
        sortByDate: Bool = true,
        startIndex: Int = 0,
        priority: FetchPriority = .high
    ) async -> Bool {
        print("📄 [FetchCoordinator] Fetch Cited By Page: \(clusterId), sortByDate: \(sortByDate), startIndex: \(startIndex)")
        
        addTask(.citedBy(clusterId: clusterId, sortByDate: sortByDate, startIndex: startIndex), priority: priority)
        await processQueue()
        return true
    }
    
    /// Fetch 全面刷新学者数据（尽可能多地获取所有信息）
    /// 这是最常用的入口，用于：Dashboard刷新、Widget更新、AutoUpdate等
    /// 内部使用: 多次调用 fetchScholarProfilePage()
    /// 获取内容: 学者信息 + 论文列表（3种排序 × 3页 = 最多10次fetch）
    public func fetchScholarComprehensive(
        scholarId: String,
        priority: FetchPriority = .high
    ) async {
        print("🚀 [FetchCoordinator] Fetch Comprehensive Scholar Data: \(scholarId) (尽可能多地获取)")
        
        // 1. 学者基本信息（通过第一页获取，最高优先级）
        _ = await fetchScholarProfilePage(scholarId: scholarId, sortBy: "total", startIndex: 0, priority: priority)
        
        // 2. 论文列表（三种排序的第一页，高优先级）
        let sortOptions = ["total", "pubdate", "title"]
        for sortBy in sortOptions {
            if sortBy != "total" {  // total 已经在上面获取了
                addTask(.scholarProfile(scholarId: scholarId, sortBy: sortBy, startIndex: 0), priority: priority)
            }
        }
        
        // 3. 后续页面预取（中优先级，尽可能多地获取，为 Who Cite Me 准备）
        for sortBy in sortOptions {
            for page in 1..<prefetchPagesCount {
                // 使用安全的乘法，防止溢出
                let startIndex = min(page * 100, Int.max - 1)
                addTask(.scholarProfile(scholarId: scholarId, sortBy: sortBy, startIndex: startIndex), priority: .medium)
            }
        }
        
        // 开始处理队列（不等待完成，避免阻塞初始化流程）
        Task {
            await processQueue()
        }
    }
    
    /// Fetch 学者的所有论文（尽可能多地预取）
    /// 用于 Who Cite Me 页面
    /// 内部使用: fetchScholarProfilePage()
    /// - Parameters:
    ///   - scholarId: 学者ID
    ///   - sortBy: 当前选择的排序方式（只获取这一种排序的第一页，立即显示）
    ///   - priority: 优先级
    ///   - onlyFirstPage: 如果为 true，只获取第一页（用于首次加载，立即显示），否则尽可能多地预取
    public func fetchScholarPublicationsWithPrefetch(
        scholarId: String,
        sortBy: String,
        priority: FetchPriority = .high,
        onlyFirstPage: Bool = false
    ) async {
        print("📋 [FetchCoordinator] Fetch Scholar Publications with Prefetch: \(scholarId), sortBy: \(sortBy), onlyFirstPage: \(onlyFirstPage)")
        
        // 添加当前选择的排序方式的第一页（高优先级，立即显示）
        _ = await fetchScholarProfilePage(scholarId: scholarId, sortBy: sortBy, startIndex: 0, priority: priority)
        
        // 如果只获取第一页，处理完第一页就返回
        if onlyFirstPage {
            // 不预取其他排序方式，只在用户实际切换排序时才获取
            return
        }
        
        // 尽可能多地预取：其他排序方式的第一页（中优先级，后台预取）
        let allSortOptions = ["total", "pubdate", "title"]
        for otherSortBy in allSortOptions where otherSortBy != sortBy {
            addTask(.scholarProfile(scholarId: scholarId, sortBy: otherSortBy, startIndex: 0), priority: .medium)
        }
        
        // 尽可能多地预取：后续页面的预取任务（中优先级，后台静默预取）
        for sortByOption in allSortOptions {
            for page in 1..<prefetchPagesCount {
                // 使用安全的乘法，防止溢出
                let startIndex = min(page * 100, Int.max - 1)
                addTask(.scholarProfile(scholarId: scholarId, sortBy: sortByOption, startIndex: startIndex), priority: .medium)
            }
        }
        
        // 开始处理队列（后台继续处理剩余任务）
        await processQueue()
    }
    
    /// 预取当前排序方式的其他页面（用于后台预取，不阻塞UI）
    /// 内部使用: fetchScholarProfilePage()
    /// - Parameters:
    ///   - scholarId: 学者ID
    ///   - sortBy: 排序方式
    ///   - pages: 要预取的页数（从第2页开始）
    public func prefetchOtherPages(scholarId: String, sortBy: String, pages: Int = 2) {
        for page in 1..<pages {
            // 使用安全的乘法，防止溢出
            let startIndex = min(page * 100, Int.max - 1)
            addTask(.scholarProfile(scholarId: scholarId, sortBy: sortBy, startIndex: startIndex), priority: .medium)
        }
        // 后台处理这些任务（不阻塞UI）
        Task {
            await processQueue()
        }
    }
    
    /// 处理队列直到第一页完成（用于立即显示）
    private func processQueueUntilFirstPageComplete() async {
        guard !isProcessingQueue else {
            print("⚠️ [FetchCoordinator] Already processing queue, will wait")
            // 如果已经在处理，等待当前处理完成
            while isProcessingQueue {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 等待 0.1 秒
            }
            return
        }
        
        isProcessingQueue = true
        isProcessing = true
        
        print("🚀 [FetchCoordinator] Processing first page task, \(taskQueue.count) tasks")
        
        // 只处理第一页的任务（startIndex == 0），应该只有1个任务
        // 先过滤出第一页的任务
        var firstPageTask: FetchTask? = nil
        
        for task in taskQueue {
            if case .scholarProfile(_, _, let startIndex) = task.type, startIndex == 0 {
                firstPageTask = task
                break
            }
        }
        
        // 处理第一页任务
        if let task = firstPageTask {
            // 从队列中移除
            if let index = taskQueue.firstIndex(where: { $0.type == task.type }) {
                taskQueue.remove(at: index)
            }
            queueSize = taskQueue.count
            
            print("▶️ [FetchCoordinator] Processing first page task: \(task.type.identifier), priority: \(task.priority), remaining: \(queueSize)")
            
            // 执行任务
            let success = await executeTask(task)
            
            if success {
                // 使用安全的加法，防止溢出（限制最大值为 Int.max - 1）
                completedTasks = min(completedTasks + 1, Int.max - 1)
                totalFetchCount = min(totalFetchCount + 1, Int.max - 1)  // 增加总fetch次数
                
                // 按页面类型统计fetch次数（防止溢出）
                let pageTypeKey = task.type.pageType.extractedContentType
                let currentCount = fetchCountByPageType[pageTypeKey, default: 0]
                fetchCountByPageType[pageTypeKey] = min(currentCount + 1, Int.max - 1)
                
                processedTasks.insert(task.type.identifier)
                print("✅ [FetchCoordinator] First page task completed: \(task.type.identifier) (Total fetches: \(totalFetchCount), \(pageTypeKey): \(fetchCountByPageType[pageTypeKey] ?? 0))")
            } else {
                // 使用安全的加法，防止溢出
                failedTasks = min(failedTasks + 1, Int.max - 1)
                print("❌ [FetchCoordinator] First page task failed: \(task.type.identifier)")
            }
        }
        
        print("✅ [FetchCoordinator] First page task completed, returning for UI update")
        isProcessingQueue = false
        isProcessing = false
        
        // 如果还有剩余任务，后台继续处理
        if !taskQueue.isEmpty {
            print("🔄 [FetchCoordinator] Continuing with \(taskQueue.count) remaining tasks in background")
            Task {
                await processQueue()
            }
        }
    }
    
    /// Fetch 引用论文（尽可能多地预取）
    /// 内部使用: fetchCitedByPage()
    /// 获取内容: 引用论文列表（2种排序 × 2页 = 最多4次fetch）
    public func fetchCitingPapersWithPrefetch(
        clusterId: String,
        priority: FetchPriority = .high
    ) async {
        print("📋 [FetchCoordinator] Fetch Citing Papers with Prefetch: \(clusterId) (尽可能多地获取)")
        
        // 添加两种排序方式的第一页（高优先级）
        _ = await fetchCitedByPage(clusterId: clusterId, sortByDate: true, startIndex: 0, priority: priority)
        addTask(.citedBy(clusterId: clusterId, sortByDate: false, startIndex: 0), priority: priority)
        
        // 尽可能多地预取：后续页面的预取任务（低优先级）
        for sortByDate in [true, false] {
            for page in 1..<2 {  // 引用列表只预取2页
                // 使用安全的乘法，防止溢出
                let startIndex = min(page * 10, Int.max - 1)
                addTask(.citedBy(clusterId: clusterId, sortByDate: sortByDate, startIndex: startIndex), priority: .low)
            }
        }
        
        // 开始处理队列
        await processQueue()
    }
    
    /// 清空任务队列
    public func clearQueue() {
        taskQueue.removeAll()
        queueSize = 0
        print("📋 [FetchCoordinator] Queue cleared")
    }
    
    /// 获取队列统计信息
    public func getQueueStats() -> (pending: Int, completed: Int, failed: Int) {
        return (queueSize, completedTasks, failedTasks)
    }
    
    /// 获取 Fetch 统计信息
    /// - Returns: (总fetch次数, 按页面类型的fetch次数统计)
    public func getFetchStats() -> (totalCount: Int, byPageType: [String: Int]) {
        return (totalFetchCount, fetchCountByPageType)
    }
    
    /// 重置 Fetch 统计
    public func resetFetchStats() {
        totalFetchCount = 0
        fetchCountByPageType.removeAll()
        print("📊 [FetchCoordinator] Fetch statistics reset")
    }
    
    // MARK: - Private Methods
    
    /// 添加任务到队列
    private func addTask(_ type: FetchTaskType, priority: FetchPriority) {
        let task = FetchTask(type: type, priority: priority, createdAt: Date())
        
        // 检查是否已在队列中
        if taskQueue.contains(where: { $0.type == type }) {
            print("⏭️ [FetchCoordinator] Task already in queue: \(task.type.identifier)")
            return
        }
        
        // 先检查缓存（如果缓存存在，标记为已处理，但不添加到队列）
        if isCached(type) {
            print("💾 [FetchCoordinator] Task data cached: \(task.type.identifier)")
            processedTasks.insert(task.type.identifier)
            return
        }
        
        // 如果任务之前被标记为已处理，但缓存不存在，说明数据可能没有正确保存
        // 清除已处理标记，允许重新 Fetch
        if processedTasks.contains(task.type.identifier) {
            print("⚠️ [FetchCoordinator] Task was marked as processed but cache is missing, re-adding: \(task.type.identifier)")
            processedTasks.remove(task.type.identifier)
        }
        
        taskQueue.append(task)
        taskQueue.sort()  // 按优先级和时间排序
        queueSize = taskQueue.count
        
        print("➕ [FetchCoordinator] Task added: \(task.type.identifier), priority: \(priority), queue size: \(queueSize)")
    }
    
    /// 检查数据是否已缓存（根据页面类型）
    private func isCached(_ type: FetchTaskType) -> Bool {
        switch type {
        case .scholarProfile(let scholarId, let sortBy, let startIndex):
            // 学者主页缓存检查
            // 必须检查对应 sortBy 的论文列表缓存是否存在
            // 对于第一页，还需要检查是否有学者信息
            if startIndex == 0 {
                // 检查统一缓存中是否有对应排序的论文列表
                let cachedPublications = UnifiedCacheManager.shared.getPublications(
                    scholarId: scholarId,
                    sortBy: sortBy,
                    startIndex: startIndex,
                    limit: 20
                )
                if let publications = cachedPublications, !publications.isEmpty {
                    return true
                }
                
                // 检查旧缓存
                if let oldCache = cacheService.getCachedScholarPublicationsList(
                    for: scholarId,
                    sortBy: sortBy,
                    startIndex: startIndex
                ), !oldCache.isEmpty {
                    return true
                }
                
                return false
            } else {
                // 非第一页：检查对应排序和起始索引的缓存
                let cachedPublications = UnifiedCacheManager.shared.getPublications(
                    scholarId: scholarId,
                    sortBy: sortBy,
                    startIndex: startIndex,
                    limit: 100
                )
                if let publications = cachedPublications, !publications.isEmpty {
                    return true
                }
                
                // 检查旧缓存
                return cacheService.getCachedScholarPublicationsList(
                    for: scholarId,
                    sortBy: sortBy,
                    startIndex: startIndex
                ) != nil
            }
            
        case .citedBy(let clusterId, let sortByDate, let startIndex):
            // 引用页面缓存检查
            return cacheService.getCachedCitingPapersList(
                for: clusterId,
                sortByDate: sortByDate,
                startIndex: startIndex
            ) != nil
        }
    }
    
    /// 处理任务队列
    private func processQueue() async {
        guard !isProcessingQueue else {
            print("⚠️ [FetchCoordinator] Already processing queue")
            return
        }
        
        isProcessingQueue = true
        isProcessing = true
        
        print("🚀 [FetchCoordinator] Starting queue processing, \(taskQueue.count) tasks")
        
        while !taskQueue.isEmpty {
            // 取出优先级最高的任务
            let task = taskQueue.removeFirst()
            queueSize = taskQueue.count
            
            print("▶️ [FetchCoordinator] Processing task: \(task.type.identifier), priority: \(task.priority), remaining: \(queueSize)")
            
            // 执行任务
            let success = await executeTask(task)
            
            if success {
                // 使用安全的加法，防止溢出（限制最大值为 Int.max - 1）
                completedTasks = min(completedTasks + 1, Int.max - 1)
                totalFetchCount = min(totalFetchCount + 1, Int.max - 1)  // 增加总fetch次数
                
                // 按页面类型统计fetch次数（防止溢出）
                let pageTypeKey = task.type.pageType.extractedContentType
                let currentCount = fetchCountByPageType[pageTypeKey, default: 0]
                fetchCountByPageType[pageTypeKey] = min(currentCount + 1, Int.max - 1)
                
                processedTasks.insert(task.type.identifier)
                print("✅ [FetchCoordinator] Task completed: \(task.type.identifier) (Total fetches: \(totalFetchCount), \(pageTypeKey): \(fetchCountByPageType[pageTypeKey] ?? 0))")
            } else {
                // 使用安全的加法，防止溢出
                failedTasks = min(failedTasks + 1, Int.max - 1)
                print("❌ [FetchCoordinator] Task failed: \(task.type.identifier)")
            }
            
            // 添加延迟，避免触发反爬虫
            let delay = Double.random(in: minDelayBetweenRequests...maxDelayBetweenRequests)
            print("⏱️ [FetchCoordinator] Waiting \(String(format: "%.1f", delay))s before next task")
            // 使用安全的乘法，防止溢出（限制最大延迟为100秒，确保不会溢出 UInt64）
            let clampedDelay = min(delay, 100.0)
            let nanosecondsValue = clampedDelay * 1_000_000_000
            // 确保不会溢出 UInt64.max (18,446,744,073,709,551,615)
            let nanoseconds = UInt64(min(nanosecondsValue, Double(UInt64.max)))
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
        
        isProcessingQueue = false
        isProcessing = false
        
        print("🏁 [FetchCoordinator] Queue processing completed. Completed: \(completedTasks), Failed: \(failedTasks)")
    }
    
    /// 执行单个任务（根据页面类型）
    private func executeTask(_ task: FetchTask) async -> Bool {
        switch task.type {
        case .scholarProfile(let scholarId, let sortBy, let startIndex):
            return await fetchScholarProfilePageContent(scholarId: scholarId, sortBy: sortBy, startIndex: startIndex)
        case .citedBy(let clusterId, let sortByDate, let startIndex):
            return await fetchCitedByPageContent(clusterId: clusterId, sortByDate: sortByDate, startIndex: startIndex)
        }
    }
    
    // MARK: - 页面内容提取和管理
    
    /// Fetch 并提取学者主页内容（尽可能多地获取，并与本地数据合并）
    /// 页面类型: scholarProfile
    /// 提取内容: 学者信息 + 论文列表
    /// 数据合并: 自动与 UnifiedCacheManager 中的已有数据合并
    private func fetchScholarProfilePageContent(scholarId: String, sortBy: String, startIndex: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            // 使用新方法获取学者信息和论文列表（尽可能多地获取）
            fetchService.fetchScholarPublicationsWithInfo(
                for: scholarId,
                sortBy: sortBy,
                startIndex: startIndex,
                forceRefresh: false
            ) { [weak self] result in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                switch result {
                case .success(let publicationsResult):
                    let publications = publicationsResult.publications
                    
                    // 1. 旧缓存（保持兼容性）- 直接保存
                    self.cacheService.cacheScholarPublicationsList(
                        publications,
                        for: scholarId,
                        sortBy: sortBy,
                        startIndex: startIndex
                    )
                    
                    print("💾 [FetchCoordinator] Cached \(publications.count) publications for \(scholarId), sortBy: \(sortBy), start: \(startIndex)")
                    
                    // 2. 新的统一缓存（自动合并本地已有数据）
                    // 注意：回调可能不在主线程，需要切换到主线程
                    Task { @MainActor in
                        // 获取本地已有数据（用于合并统计）
                        let existingPublications = UnifiedCacheManager.shared.getPublications(
                            scholarId: scholarId,
                            sortBy: sortBy,
                            startIndex: startIndex,
                            limit: Int.max
                        ) ?? []
                        
                        if let scholarInfo = publicationsResult.scholarInfo {
                            // 有学者信息：保存完整快照（UnifiedCacheManager会自动合并）
                            let snapshot = ScholarDataSnapshot(
                                scholarId: scholarId,
                                timestamp: Date(),
                                scholarName: scholarInfo.name,
                                totalCitations: scholarInfo.totalCitations,
                                hIndex: scholarInfo.hIndex,
                                i10Index: scholarInfo.i10Index,
                                publications: publications,
                                sortBy: sortBy,
                                startIndex: startIndex,
                                source: .scholarProfile
                            )
                            // 保存快照（增量更新：只更新引用数发生变化的论文）
                            UnifiedCacheManager.shared.saveDataSnapshot(snapshot)
                            
                            // 合并统计（获取合并后的总数）
                            let mergedCount = UnifiedCacheManager.shared.getPublications(
                                scholarId: scholarId,
                                sortBy: sortBy,
                                startIndex: 0,
                                limit: Int.max
                            )?.count ?? 0
                            
                            print("📦 [FetchCoordinator] Saved to unified cache: \(scholarInfo.name), \(scholarInfo.totalCitations) citations")
                            print("🔗 [FetchCoordinator] Incremental update: \(existingPublications.count) existing → \(mergedCount) total (only updated changed citations)")
                        } else if startIndex == 0 {
                            // 第一页但没有学者信息，只保存论文列表（自动合并）
                            let snapshot = ScholarDataSnapshot(
                                scholarId: scholarId,
                                timestamp: Date(),
                                scholarName: nil,
                                totalCitations: nil,
                                hIndex: nil,
                                i10Index: nil,
                                publications: publications,
                                sortBy: sortBy,
                                startIndex: startIndex,
                                source: .scholarProfile
                            )
                            // 保存快照（增量更新：只更新引用数发生变化的论文）
                            UnifiedCacheManager.shared.saveDataSnapshot(snapshot)
                            
                            let mergedCount = UnifiedCacheManager.shared.getPublications(
                                scholarId: scholarId,
                                sortBy: sortBy,
                                startIndex: 0,
                                limit: Int.max
                            )?.count ?? 0
                            
                            print("📦 [FetchCoordinator] Saved publications to unified cache (no scholar info)")
                            print("🔗 [FetchCoordinator] Incremental update: \(existingPublications.count) existing → \(mergedCount) total (only updated changed citations)")
                        } else {
                            // 非第一页：只保存论文列表（自动合并）
                            let snapshot = ScholarDataSnapshot(
                                scholarId: scholarId,
                                timestamp: Date(),
                                scholarName: nil,
                                totalCitations: nil,
                                hIndex: nil,
                                i10Index: nil,
                                publications: publications,
                                sortBy: sortBy,
                                startIndex: startIndex,
                                source: .scholarProfile
                            )
                            // 保存快照（增量更新：只更新引用数发生变化的论文）
                            UnifiedCacheManager.shared.saveDataSnapshot(snapshot)
                            
                            let mergedCount = UnifiedCacheManager.shared.getPublications(
                                scholarId: scholarId,
                                sortBy: sortBy,
                                startIndex: 0,
                                limit: Int.max
                            )?.count ?? 0
                            
                            print("🔗 [FetchCoordinator] Incremental update page \(startIndex/100 + 1): \(existingPublications.count) existing → \(mergedCount) total (only updated changed citations)")
                        }
                    }
                    
                    continuation.resume(returning: true)
                    
                case .failure(let error):
                    print("❌ [FetchCoordinator] Failed to fetch publications: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// Fetch 并提取引用页面内容（尽可能多地获取，并与本地数据合并）
    /// 页面类型: citedBy
    /// 提取内容: 引用论文列表
    /// 数据合并: 自动与本地缓存中的已有数据合并
    private func fetchCitedByPageContent(clusterId: String, sortByDate: Bool, startIndex: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            fetchService.fetchCitingPapersForClusterId(
                clusterId,
                startIndex: startIndex,
                sortByDate: sortByDate
            ) { [weak self] result in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                switch result {
                case .success(let papers):
                    // 获取本地已有数据（用于合并统计）
                    let existingPapers = self.cacheService.getCachedCitingPapersList(
                        for: clusterId,
                        sortByDate: sortByDate,
                        startIndex: startIndex
                    ) ?? []
                    
                    // 缓存数据（如果已有数据，会覆盖；否则新增）
                    self.cacheService.cacheCitingPapersList(
                        papers,
                        for: clusterId,
                        sortByDate: sortByDate,
                        startIndex: startIndex
                    )
                    
                    // 合并统计
                    let sortKey = sortByDate ? "true" : "false"
                    let allCached = self.cacheService.getCachedCitingPapersList(
                        for: clusterId,
                        sortByDate: sortByDate,
                        startIndex: 0
                    ) ?? []
                    
                    print("💾 [FetchCoordinator] Cached \(papers.count) citing papers for \(clusterId), sortByDate: \(sortByDate), start: \(startIndex)")
                    print("🔗 [FetchCoordinator] Merged with local data: \(existingPapers.count) existing + \(papers.count) new = \(allCached.count) total (sortByDate: \(sortKey))")
                    
                    continuation.resume(returning: true)
                    
                case .failure(let error):
                    print("❌ [FetchCoordinator] Failed to fetch citing papers: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

