import Foundation
import Combine

// MARK: - 统一数据快照模型
/// 从一次 Google Scholar 访问中能获取的所有信息
public struct ScholarDataSnapshot {
    public let scholarId: String
    public let timestamp: Date
    
    // 学者基本信息
    public let scholarName: String?
    public let totalCitations: Int?
    public let hIndex: Int?
    public let i10Index: Int?
    
    // 论文列表（可能只是部分，取决于排序和分页）
    public let publications: [ScholarPublication]
    public let sortBy: String  // "total", "pubdate", "title"
    public let startIndex: Int  // 分页起始索引
    
    // 元数据
    public let source: DataSource
    
    public enum DataSource: String, Codable {
        case scholarProfile = "scholar_profile"  // 学者主页
        case whoCiteMe = "who_cite_me"          // Who Cite Me 页面
        case dashboard = "dashboard"             // Dashboard 刷新
        case autoUpdate = "auto_update"          // 自动更新
        case widget = "widget"                   // Widget 刷新
    }
    
    public init(
        scholarId: String,
        timestamp: Date = Date(),
        scholarName: String? = nil,
        totalCitations: Int? = nil,
        hIndex: Int? = nil,
        i10Index: Int? = nil,
        publications: [ScholarPublication],
        sortBy: String,
        startIndex: Int,
        source: DataSource
    ) {
        self.scholarId = scholarId
        self.timestamp = timestamp
        self.scholarName = scholarName
        self.totalCitations = totalCitations
        self.hIndex = hIndex
        self.i10Index = i10Index
        self.publications = publications
        self.sortBy = sortBy
        self.startIndex = startIndex
        self.source = source
    }
}

// MARK: - 统一缓存管理器
/// 全局统一的缓存管理器，负责：
/// 1. 存储所有从 Google Scholar 获取的数据
/// 2. 为不同的 UI 模块提供数据视图
/// 3. 检测和通知数据变化
@MainActor
public class UnifiedCacheManager: ObservableObject {
    public static let shared = UnifiedCacheManager()
    
    // MARK: - Published Properties（UI 订阅用）
    
    /// 学者基本信息缓存（scholarId -> 最新的基本信息）
    @Published public private(set) var scholarBasicInfo: [String: ScholarBasicInfo] = [:]
    
    /// 论文列表缓存（scholarId -> sortBy -> 所有页面的论文）
    @Published public private(set) var scholarPublications: [String: [String: [ScholarPublication]]] = [:]
    
    /// 引用文章缓存（clusterId -> sortByDate -> 所有页面的引用文章）
    @Published public private(set) var citingPapersCache: [String: [String: [CitingPaper]]] = [:]
    
    /// 数据变化通知（用于 Who Cite Me 等模块监听变化）
    public let dataChangePublisher = PassthroughSubject<DataChangeEvent, Never>()
    
    // MARK: - Private Storage
    
    /// 原始数据快照存储（按时间顺序，用于审计和回溯）
    private var dataSnapshots: [String: [ScholarDataSnapshot]] = [:]  // scholarId -> snapshots
    
    /// 缓存过期时间（24小时）
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60
    
    /// 持久化存储键
    private let persistenceKey = "UnifiedCacheManager_Data"
    
    private init() {
        print("📦 [UnifiedCache] Initialized")
        // 从持久化存储加载数据
        loadPersistedData()
    }
    
    // MARK: - 持久化
    
    /// 从持久化存储加载数据
    private func loadPersistedData() {
        let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
        guard let data = appGroupDefaults.data(forKey: persistenceKey),
              let persisted = try? JSONDecoder().decode(PersistedCacheData.self, from: data) else {
            print("📦 [UnifiedCache] No persisted data found, starting fresh")
            return
        }
        
        // 检查缓存是否过期
        let now = Date()
        if let lastSaved = persisted.lastSaved,
           now.timeIntervalSince(lastSaved) > cacheExpirationInterval {
            print("📦 [UnifiedCache] Persisted data expired, clearing")
            clearPersistedData()
            return
        }
        
        // 恢复学者基本信息
        scholarBasicInfo = persisted.scholarBasicInfo
        
        // 恢复论文列表
        scholarPublications = persisted.scholarPublications
        
        // 恢复引用文章缓存
        citingPapersCache = persisted.citingPapersCache
        
        let publicationCount = scholarPublications.values.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } }
        let citingPapersCount = citingPapersCache.values.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } }
        print("📦 [UnifiedCache] Loaded persisted data: \(scholarBasicInfo.count) scholars, \(publicationCount) publications, \(citingPapersCount) citing papers")
    }
    
    /// 保存数据到持久化存储
    private func persistData() {
        let persisted = PersistedCacheData(
            scholarBasicInfo: scholarBasicInfo,
            scholarPublications: scholarPublications,
            citingPapersCache: citingPapersCache,
            lastSaved: Date()
        )
        
        guard let data = try? JSONEncoder().encode(persisted) else {
            print("❌ [UnifiedCache] Failed to encode data for persistence")
            return
        }
        
        let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
        appGroupDefaults.set(data, forKey: persistenceKey)
        appGroupDefaults.synchronize()
        print("💾 [UnifiedCache] Persisted data to disk")
    }
    
    /// 清除持久化数据
    private func clearPersistedData() {
        let appGroupDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
        appGroupDefaults.removeObject(forKey: persistenceKey)
        appGroupDefaults.synchronize()
    }
    
    /// 持久化的缓存数据结构
    private struct PersistedCacheData: Codable {
        let scholarBasicInfo: [String: ScholarBasicInfo]
        let scholarPublications: [String: [String: [ScholarPublication]]]
        let citingPapersCache: [String: [String: [CitingPaper]]]  // clusterId -> sortByDate -> papers
        let lastSaved: Date?
    }
    
    // MARK: - 数据变化事件
    
    public enum DataChangeEvent {
        case scholarInfoUpdated(scholarId: String, oldCitations: Int?, newCitations: Int?)
        case publicationsUpdated(scholarId: String, sortBy: String, count: Int)
        case newPublicationsDetected(scholarId: String, newCount: Int)
        case citingPapersUpdated(clusterId: String, count: Int)
    }
    
    // MARK: - 学者基本信息
    
    public struct ScholarBasicInfo: Codable {
        public let scholarId: String
        public let name: String
        public let citations: Int
        public let hIndex: Int?
        public let i10Index: Int?
        public let lastUpdated: Date
        public let source: ScholarDataSnapshot.DataSource
        
        public init(
            scholarId: String,
            name: String,
            citations: Int,
            hIndex: Int? = nil,
            i10Index: Int? = nil,
            lastUpdated: Date = Date(),
            source: ScholarDataSnapshot.DataSource
        ) {
            self.scholarId = scholarId
            self.name = name
            self.citations = citations
            self.hIndex = hIndex
            self.i10Index = i10Index
            self.lastUpdated = lastUpdated
            self.source = source
        }
    }
    
    // MARK: - 核心方法：保存数据快照
    
    /// 保存从 Google Scholar 获取的数据快照
    /// 这是唯一的数据入口，所有从 Google Scholar 获取的数据都应该通过这个方法保存
    public func saveDataSnapshot(_ snapshot: ScholarDataSnapshot) {
        print("📥 [UnifiedCache] Saving snapshot for \(snapshot.scholarId), source: \(snapshot.source.rawValue), \(snapshot.publications.count) publications")
        
        // 1. 保存原始快照
        if dataSnapshots[snapshot.scholarId] == nil {
            dataSnapshots[snapshot.scholarId] = []
        }
        dataSnapshots[snapshot.scholarId]?.append(snapshot)
        
        // 2. 更新学者基本信息（如果有）
        if let name = snapshot.scholarName, let citations = snapshot.totalCitations {
            let oldInfo = scholarBasicInfo[snapshot.scholarId]
            let newInfo = ScholarBasicInfo(
                scholarId: snapshot.scholarId,
                name: name,
                citations: citations,
                hIndex: snapshot.hIndex,
                i10Index: snapshot.i10Index,
                lastUpdated: snapshot.timestamp,
                source: snapshot.source
            )
            scholarBasicInfo[snapshot.scholarId] = newInfo
            
            // 发送变化通知
            dataChangePublisher.send(
                .scholarInfoUpdated(
                    scholarId: snapshot.scholarId,
                    oldCitations: oldInfo?.citations,
                    newCitations: citations
                )
            )
            
            // 持久化
            persistData()
            
            print("✅ [UnifiedCache] Updated basic info: \(name), citations: \(citations)")
        }
        
        // 3. 更新论文列表
        if !snapshot.publications.isEmpty {
            if scholarPublications[snapshot.scholarId] == nil {
                scholarPublications[snapshot.scholarId] = [:]
            }
            if scholarPublications[snapshot.scholarId]?[snapshot.sortBy] == nil {
                scholarPublications[snapshot.scholarId]?[snapshot.sortBy] = []
            }
            
            // 合并论文列表（去重）
            let existingPublications = scholarPublications[snapshot.scholarId]?[snapshot.sortBy] ?? []
            let mergedPublications = mergePublications(
                existing: existingPublications,
                new: snapshot.publications,
                startIndex: snapshot.startIndex
            )
            
            scholarPublications[snapshot.scholarId]?[snapshot.sortBy] = mergedPublications
            
            // 发送变化通知
            dataChangePublisher.send(
                .publicationsUpdated(
                    scholarId: snapshot.scholarId,
                    sortBy: snapshot.sortBy,
                    count: mergedPublications.count
                )
            )
            
            print("✅ [UnifiedCache] Updated publications: \(mergedPublications.count) total, sortBy: \(snapshot.sortBy)")
            
            // 持久化
            persistData()
        }
    }
    
    // MARK: - 数据获取方法
    
    /// 获取学者基本信息
    public func getScholarBasicInfo(scholarId: String) -> ScholarBasicInfo? {
        guard let info = scholarBasicInfo[scholarId] else {
            return nil
        }
        
        // 检查缓存是否过期
        if Date().timeIntervalSince(info.lastUpdated) > cacheExpirationInterval {
            print("⚠️ [UnifiedCache] Basic info expired for \(scholarId)")
            return nil
        }
        
        return info
    }
    
    /// 获取论文列表
    public func getPublications(
        scholarId: String,
        sortBy: String,
        startIndex: Int = 0,
        limit: Int = 100
    ) -> [ScholarPublication]? {
        guard let publicationsBySort = scholarPublications[scholarId],
              let publications = publicationsBySort[sortBy] else {
            return nil
        }
        
        // 返回指定范围的论文
        let endIndex = min(startIndex + limit, publications.count)
        guard startIndex < publications.count else {
            return []
        }
        
        return Array(publications[startIndex..<endIndex])
    }
    
    /// 检查是否需要获取更多论文
    public func needsFetchMore(
        scholarId: String,
        sortBy: String,
        requestedIndex: Int
    ) -> Bool {
        guard let publicationsBySort = scholarPublications[scholarId],
              let publications = publicationsBySort[sortBy] else {
            return true  // 没有缓存，需要获取
        }
        
        // 如果请求的索引超出当前缓存的范围，需要获取更多
        return requestedIndex >= publications.count
    }
    
    // MARK: - 辅助方法
    
    /// 合并论文列表（处理分页和去重）
    private func mergePublications(
        existing: [ScholarPublication],
        new: [ScholarPublication],
        startIndex: Int
    ) -> [ScholarPublication] {
        var result = existing
        
        // 如果是第一页（startIndex == 0），直接替换
        if startIndex == 0 {
            result = new
        } else {
            // 否则，追加新数据（但要去重）
            let existingIds = Set(existing.compactMap { $0.clusterId })
            let newUnique = new.filter { pub in
                guard let id = pub.clusterId else { return true }
                return !existingIds.contains(id)
            }
            result.append(contentsOf: newUnique)
        }
        
        return result
    }
    
    /// 清除学者的所有缓存
    public func clearCache(for scholarId: String) {
        scholarBasicInfo.removeValue(forKey: scholarId)
        scholarPublications.removeValue(forKey: scholarId)
        dataSnapshots.removeValue(forKey: scholarId)
        
        // 持久化
        persistData()
        
        print("🗑️ [UnifiedCache] Cleared cache for \(scholarId)")
    }
    
    /// 清除所有缓存
    public func clearAllCache() {
        scholarBasicInfo.removeAll()
        scholarPublications.removeAll()
        citingPapersCache.removeAll()
        dataSnapshots.removeAll()
        
        // 持久化
        persistData()
        
        // 清除持久化数据
        clearPersistedData()
        
        print("🗑️ [UnifiedCache] Cleared all cache")
    }
    
    // MARK: - 调试方法
    
    /// 获取缓存统计信息
    public func getCacheStats() -> CacheStats {
        return CacheStats(
            scholarCount: scholarBasicInfo.count,
            publicationCount: scholarPublications.values.reduce(0) { count, sortDict in
                count + sortDict.values.reduce(0) { $0 + $1.count }
            },
            snapshotCount: dataSnapshots.values.reduce(0) { $0 + $1.count }
        )
    }
    
    public struct CacheStats {
        public let scholarCount: Int
        public let publicationCount: Int
        public let snapshotCount: Int
    }
}

