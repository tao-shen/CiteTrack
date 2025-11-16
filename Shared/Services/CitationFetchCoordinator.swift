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

/// 获取任务类型
enum FetchTaskType: Hashable {
    case scholarBasicInfo(scholarId: String)  // 学者基本信息（名字+引用数）
    case scholarPublications(scholarId: String, sortBy: String, startIndex: Int)  // 学者论文列表
    case citingPapers(clusterId: String, sortByDate: Bool, startIndex: Int)  // 引用论文列表
    
    var identifier: String {
        switch self {
        case .scholarBasicInfo(let scholarId):
            return "basic_\(scholarId)"
        case .scholarPublications(let scholarId, let sortBy, let startIndex):
            return "scholar_\(scholarId)_\(sortBy)_\(startIndex)"
        case .citingPapers(let clusterId, let sortByDate, let startIndex):
            return "citing_\(clusterId)_\(sortByDate)_\(startIndex)"
        }
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
    
    // MARK: - Private Properties
    
    private var taskQueue: [FetchTask] = []
    private var processedTasks: Set<String> = []  // 已处理的任务标识符
    private var isProcessingQueue = false
    
    private let fetchService = CitationFetchService.shared
    private let cacheService = CitationCacheService.shared
    
    // 配置参数
    private let minDelayBetweenRequests: TimeInterval = 2.0  // 最小请求间隔（减少延迟）
    private let maxDelayBetweenRequests: TimeInterval = 3.0  // 最大请求间隔（减少延迟）
    private let maxConcurrentTasks = 1  // 最大并发任务数（避免被封）
    private let prefetchPagesCount = 3  // 预取的页数
    
    private init() {
        print("📋 [FetchCoordinator] Initialized")
    }
    
    // MARK: - Public API
    
    /// 全面刷新学者数据（一次访问获取所有信息）
    /// 这是最常用的入口，用于：Dashboard刷新、Widget更新、AutoUpdate等
    public func fetchScholarComprehensive(
        scholarId: String,
        priority: FetchPriority = .high
    ) async {
        print("🚀 [FetchCoordinator] Comprehensive fetch for scholar: \(scholarId)")
        
        // 1. 学者基本信息（最高优先级，UI需要）
        addTask(.scholarBasicInfo(scholarId: scholarId), priority: priority)
        
        // 2. 论文列表（三种排序的第一页，高优先级）
        let sortOptions = ["total", "pubdate", "title"]
        for sortBy in sortOptions {
            addTask(.scholarPublications(scholarId: scholarId, sortBy: sortBy, startIndex: 0), priority: priority)
        }
        
        // 3. 后续页面预取（中优先级，为 Who Cite Me 准备）
        for sortBy in sortOptions {
            for page in 1..<prefetchPagesCount {
                let startIndex = page * 100
                addTask(.scholarPublications(scholarId: scholarId, sortBy: sortBy, startIndex: startIndex), priority: .medium)
            }
        }
        
        // 开始处理队列
        await processQueue()
    }
    
    /// 获取学者的所有论文（包含预取）
    /// 用于 Who Cite Me 页面
    /// - Parameters:
    ///   - scholarId: 学者ID
    ///   - sortBy: 当前选择的排序方式（只获取这一种排序的第一页，立即显示）
    ///   - priority: 优先级
    ///   - onlyFirstPage: 如果为 true，只获取第一页（用于首次加载，立即显示），否则预取所有页面
    public func fetchScholarPublicationsWithPrefetch(
        scholarId: String,
        sortBy: String,
        priority: FetchPriority = .high,
        onlyFirstPage: Bool = false
    ) async {
        print("📋 [FetchCoordinator] Starting prefetch for scholar publications: \(scholarId), sortBy: \(sortBy), onlyFirstPage: \(onlyFirstPage)")
        
        // 添加当前选择的排序方式的第一页（高优先级，立即显示）
        addTask(.scholarPublications(scholarId: scholarId, sortBy: sortBy, startIndex: 0), priority: priority)
        
        // 如果只获取第一页，处理完第一页就返回
        if onlyFirstPage {
            // 只处理第一页的任务（当前排序方式）
            await processQueueUntilFirstPageComplete()
            // 不预取其他排序方式，只在用户实际切换排序时才获取
            return
        }
        
        // 添加其他排序方式的第一页（中优先级，后台预取）
        let allSortOptions = ["total", "pubdate", "title"]
        for otherSortBy in allSortOptions where otherSortBy != sortBy {
            addTask(.scholarPublications(scholarId: scholarId, sortBy: otherSortBy, startIndex: 0), priority: .medium)
        }
        
        // 添加后续页面的预取任务（中优先级，后台静默预取）
        for sortByOption in allSortOptions {
            for page in 1..<prefetchPagesCount {
                let startIndex = page * 100
                addTask(.scholarPublications(scholarId: scholarId, sortBy: sortByOption, startIndex: startIndex), priority: .medium)
            }
        }
        
        // 开始处理队列（后台继续处理剩余任务）
        await processQueue()
    }
    
    /// 预取当前排序方式的其他页面（用于后台预取，不阻塞UI）
    /// - Parameters:
    ///   - scholarId: 学者ID
    ///   - sortBy: 排序方式
    ///   - pages: 要预取的页数（从第2页开始）
    public func prefetchOtherPages(scholarId: String, sortBy: String, pages: Int = 2) {
        for page in 1..<pages {
            let startIndex = page * 100
            addTask(.scholarPublications(scholarId: scholarId, sortBy: sortBy, startIndex: startIndex), priority: .medium)
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
            if case .scholarPublications(_, _, let startIndex) = task.type, startIndex == 0 {
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
                completedTasks += 1
                processedTasks.insert(task.type.identifier)
                print("✅ [FetchCoordinator] First page task completed: \(task.type.identifier)")
            } else {
                failedTasks += 1
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
    
    /// 获取引用论文（包含预取）
    public func fetchCitingPapersWithPrefetch(
        clusterId: String,
        priority: FetchPriority = .high
    ) async {
        print("📋 [FetchCoordinator] Starting prefetch for citing papers: \(clusterId)")
        
        // 添加两种排序方式的第一页（高优先级）
        addTask(.citingPapers(clusterId: clusterId, sortByDate: true, startIndex: 0), priority: priority)
        addTask(.citingPapers(clusterId: clusterId, sortByDate: false, startIndex: 0), priority: priority)
        
        // 添加后续页面的预取任务（低优先级）
        for sortByDate in [true, false] {
            for page in 1..<2 {  // 引用列表只预取2页
                let startIndex = page * 10
                addTask(.citingPapers(clusterId: clusterId, sortByDate: sortByDate, startIndex: startIndex), priority: .low)
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
    
    // MARK: - Private Methods
    
    /// 添加任务到队列
    private func addTask(_ type: FetchTaskType, priority: FetchPriority) {
        let task = FetchTask(type: type, priority: priority, createdAt: Date())
        
        // 检查是否已经处理过或已在队列中
        if processedTasks.contains(task.type.identifier) {
            print("⏭️ [FetchCoordinator] Task already processed: \(task.type.identifier)")
            return
        }
        
        if taskQueue.contains(where: { $0.type == type }) {
            print("⏭️ [FetchCoordinator] Task already in queue: \(task.type.identifier)")
            return
        }
        
        // 检查缓存
        if isCached(type) {
            print("💾 [FetchCoordinator] Task data cached: \(task.type.identifier)")
            processedTasks.insert(task.type.identifier)
            return
        }
        
        taskQueue.append(task)
        taskQueue.sort()  // 按优先级和时间排序
        queueSize = taskQueue.count
        
        print("➕ [FetchCoordinator] Task added: \(task.type.identifier), priority: \(priority), queue size: \(queueSize)")
    }
    
    /// 检查数据是否已缓存
    private func isCached(_ type: FetchTaskType) -> Bool {
        switch type {
        case .scholarBasicInfo(let scholarId):
            // 基本信息缓存检查（使用论文列表的缓存作为判断依据）
            return cacheService.getCachedScholarPublicationsList(
                for: scholarId,
                sortBy: "total",
                startIndex: 0
            ) != nil
        case .scholarPublications(let scholarId, let sortBy, let startIndex):
            return cacheService.getCachedScholarPublicationsList(
                for: scholarId,
                sortBy: sortBy,
                startIndex: startIndex
            ) != nil
        case .citingPapers(let clusterId, let sortByDate, let startIndex):
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
                completedTasks += 1
                processedTasks.insert(task.type.identifier)
                print("✅ [FetchCoordinator] Task completed: \(task.type.identifier)")
            } else {
                failedTasks += 1
                print("❌ [FetchCoordinator] Task failed: \(task.type.identifier)")
            }
            
            // 添加延迟，避免触发反爬虫
            let delay = Double.random(in: minDelayBetweenRequests...maxDelayBetweenRequests)
            print("⏱️ [FetchCoordinator] Waiting \(String(format: "%.1f", delay))s before next task")
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        isProcessingQueue = false
        isProcessing = false
        
        print("🏁 [FetchCoordinator] Queue processing completed. Completed: \(completedTasks), Failed: \(failedTasks)")
    }
    
    /// 执行单个任务
    private func executeTask(_ task: FetchTask) async -> Bool {
        switch task.type {
        case .scholarBasicInfo(let scholarId):
            return await fetchScholarBasicInfo(scholarId: scholarId)
        case .scholarPublications(let scholarId, let sortBy, let startIndex):
            return await fetchScholarPublications(scholarId: scholarId, sortBy: sortBy, startIndex: startIndex)
        case .citingPapers(let clusterId, let sortByDate, let startIndex):
            return await fetchCitingPapers(clusterId: clusterId, sortByDate: sortByDate, startIndex: startIndex)
        }
    }
    
    /// 获取学者基本信息（名字 + 引用数）
    private func fetchScholarBasicInfo(scholarId: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            // 通过获取论文列表第一页来获取基本信息
            // Google Scholar 的学者页面同时包含基本信息和论文列表
            fetchService.fetchScholarPublications(
                for: scholarId,
                sortBy: "total",
                startIndex: 0,
                forceRefresh: false
            ) { [weak self] result in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }
                
                switch result {
                case .success(let publications):
                    // 缓存论文数据（同时也缓存了基本信息）
                    self.cacheService.cacheScholarPublicationsList(
                        publications,
                        for: scholarId,
                        sortBy: "total",
                        startIndex: 0
                    )
                    
                    print("💾 [FetchCoordinator] Cached basic info + \(publications.count) publications for \(scholarId)")
                    continuation.resume(returning: true)
                    
                case .failure(let error):
                    print("❌ [FetchCoordinator] Failed to fetch basic info: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// 获取学者论文列表
    private func fetchScholarPublications(scholarId: String, sortBy: String, startIndex: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            fetchService.fetchScholarPublications(
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
                case .success(let publications):
                    // 缓存数据
                    self.cacheService.cacheScholarPublicationsList(
                        publications,
                        for: scholarId,
                        sortBy: sortBy,
                        startIndex: startIndex
                    )
                    
                    print("💾 [FetchCoordinator] Cached \(publications.count) publications for \(scholarId), sortBy: \(sortBy), start: \(startIndex)")
                    continuation.resume(returning: true)
                    
                case .failure(let error):
                    print("❌ [FetchCoordinator] Failed to fetch publications: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// 获取引用论文列表
    private func fetchCitingPapers(clusterId: String, sortByDate: Bool, startIndex: Int) async -> Bool {
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
                    // 缓存数据
                    self.cacheService.cacheCitingPapersList(
                        papers,
                        for: clusterId,
                        sortByDate: sortByDate,
                        startIndex: startIndex
                    )
                    
                    print("💾 [FetchCoordinator] Cached \(papers.count) citing papers for \(clusterId), sortByDate: \(sortByDate), start: \(startIndex)")
                    continuation.resume(returning: true)
                    
                case .failure(let error):
                    print("❌ [FetchCoordinator] Failed to fetch citing papers: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

