import Foundation
import Combine
import UserNotifications

/// 引用变化通知服务
/// 监听学者数据更新，检测论文引用量变化，并发送通知
@MainActor
public class CitationChangeNotificationService: ObservableObject {
    public static let shared = CitationChangeNotificationService()
    
    private var cancellables = Set<AnyCancellable>()
    private let fetchCoordinator = CitationFetchCoordinator.shared
    private let cacheService = CitationCacheService.shared
    private let notificationService = NotificationService.shared
    
    // 存储每个论文的引用列表（用于对比）
    // clusterId -> [CitingPaper.id]
    private var previousCitingPaperIds: [String: Set<String>] = [:]
    
    // 存储每个学者的论文引用量（用于检测变化）
    // scholarId -> [clusterId: citationCount]
    private var previousCitationCounts: [String: [String: Int]] = [:]
    
    private init() {
        setupSubscription()
        print("🔔 [CitationChangeNotification] Service initialized")
    }
    
    // MARK: - Setup
    
    private func setupSubscription() {
        // 订阅统一缓存的数据变化事件
        UnifiedCacheManager.shared.dataChangePublisher
            .sink { [weak self] change in
                Task { @MainActor in
                    await self?.handleDataChange(change)
                }
            }
            .store(in: &cancellables)
        
        print("🔔 [CitationChangeNotification] Subscribed to unified cache changes")
    }
    
    // MARK: - Handle Data Changes
    
    private func handleDataChange(_ change: UnifiedCacheManager.DataChangeEvent) async {
        switch change {
        case .publicationsUpdated(let scholarId, let sortBy, let count):
            await handlePublicationsUpdated(scholarId: scholarId, sortBy: sortBy, count: count)
            
        case .scholarInfoUpdated(let scholarId, let oldCitations, let newCitations):
            // 学者总引用数变化，可以发送通知
            if let old = oldCitations, let new = newCitations, old != new {
                print("🔔 [CitationChangeNotification] Scholar \(scholarId) total citations changed: \(old) → \(new)")
            }
            
        case .newPublicationsDetected(let scholarId, let newCount):
            print("🔔 [CitationChangeNotification] New publications detected for \(scholarId): \(newCount)")
            
        case .citingPapersUpdated(let clusterId, let count):
            await handleCitingPapersUpdated(clusterId: clusterId, count: count)
        }
    }
    
    /// 处理论文列表更新
    private func handlePublicationsUpdated(scholarId: String, sortBy: String, count: Int) async {
        // 获取当前论文列表
        guard let publications = UnifiedCacheManager.shared.getPublications(
            scholarId: scholarId,
            sortBy: sortBy,
            startIndex: 0,
            limit: 100
        ) else {
            return
        }
        
        // 获取之前的引用量记录
        let previousCounts = previousCitationCounts[scholarId] ?? [:]
        var currentCounts: [String: Int] = [:]
        var changedPublications: [(clusterId: String, title: String, oldCount: Int, newCount: Int)] = []
        
        // 检测引用量变化的论文
        for publication in publications {
            guard let clusterId = publication.clusterId,
                  let newCount = publication.citationCount else {
                continue
            }
            
            currentCounts[clusterId] = newCount
            
            if let oldCount = previousCounts[clusterId], oldCount != newCount {
                // 引用量发生变化
                changedPublications.append((
                    clusterId: clusterId,
                    title: publication.title,
                    oldCount: oldCount,
                    newCount: newCount
                ))
                print("🔔 [CitationChangeNotification] Publication citation count changed: '\(publication.title.prefix(50))...' \(oldCount) → \(newCount)")
            } else if previousCounts[clusterId] == nil && newCount > 0 {
                // 新论文，有引用量
                changedPublications.append((
                    clusterId: clusterId,
                    title: publication.title,
                    oldCount: 0,
                    newCount: newCount
                ))
            }
        }
        
        // 更新引用量记录
        previousCitationCounts[scholarId] = currentCounts
        
        // 对于引用量变化的论文，检查是否有新的引用
        for changedPub in changedPublications {
            // 只有当引用量增加时才检查新引用
            if changedPub.newCount > changedPub.oldCount {
                await checkForNewCitingPapers(
                    clusterId: changedPub.clusterId,
                    publicationTitle: changedPub.title,
                    scholarId: scholarId
                )
            }
        }
    }
    
    /// 处理引用论文列表更新
    private func handleCitingPapersUpdated(clusterId: String, count: Int) async {
        // 这个方法会在引用列表更新后调用
        // 但我们需要在 handlePublicationsUpdated 中主动 Fetch 引用列表
        print("🔔 [CitationChangeNotification] Citing papers updated for cluster \(clusterId): \(count)")
    }
    
    // MARK: - Check for New Citing Papers
    
    /// 检查论文是否有新的引用
    private func checkForNewCitingPapers(clusterId: String, publicationTitle: String, scholarId: String) async {
        print("🔔 [CitationChangeNotification] Checking for new citing papers: \(clusterId)")
        
        // 获取之前的引用列表 ID
        let previousIds = previousCitingPaperIds[clusterId] ?? Set<String>()
        
        // Fetch 最新的引用列表（按日期排序，获取第一页）
        let success = await fetchCoordinator.fetchCitedByPage(
            clusterId: clusterId,
            sortByDate: true,
            startIndex: 0,
            priority: .medium
        )
        
        if !success {
            print("⚠️ [CitationChangeNotification] Failed to fetch citing papers for \(clusterId)")
            return
        }
        
        // 等待一小段时间，确保数据已保存到缓存
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 从缓存获取最新的引用列表
        guard let currentCitingPapers = cacheService.getCachedCitingPapersList(
            for: clusterId,
            sortByDate: true,
            startIndex: 0
        ) else {
            print("⚠️ [CitationChangeNotification] No citing papers found in cache for \(clusterId)")
            return
        }
        
        // 获取当前引用列表的 ID
        let currentIds = Set(currentCitingPapers.map { $0.id })
        
        // 找出新增的引用
        let newIds = currentIds.subtracting(previousIds)
        
        if !newIds.isEmpty {
            // 找出新增的引用论文
            let newCitingPapers = currentCitingPapers.filter { newIds.contains($0.id) }
            
            // 更新之前的引用列表 ID
            previousCitingPaperIds[clusterId] = currentIds
            
            // 发送通知
            for newPaper in newCitingPapers {
                await sendNewCitationNotification(
                    publicationTitle: publicationTitle,
                    citingPaperTitle: newPaper.title,
                    citingPaperAuthors: newPaper.authorsDisplay,
                    clusterId: clusterId,
                    scholarId: scholarId
                )
            }
        } else {
            // 更新之前的引用列表 ID（即使没有新引用，也要更新，避免下次重复检查）
            previousCitingPaperIds[clusterId] = currentIds
        }
    }
    
    // MARK: - Send Notifications
    
    /// 发送新引用通知
    private func sendNewCitationNotification(
        publicationTitle: String,
        citingPaperTitle: String,
        citingPaperAuthors: String,
        clusterId: String,
        scholarId: String
    ) async {
        // 检查通知权限
        guard notificationService.notificationsEnabled else {
            print("⚠️ [CitationChangeNotification] Notifications not enabled")
            return
        }
        
        // 构建通知内容
        let title = "新引用"
        let body = "《\(publicationTitle.prefix(50))\(publicationTitle.count > 50 ? "..." : "")》被《\(citingPaperTitle.prefix(50))\(citingPaperTitle.count > 50 ? "..." : "")》引用"
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        // 设置用户信息
        content.userInfo = [
            "type": "new_citation",
            "publication_title": publicationTitle,
            "citing_paper_title": citingPaperTitle,
            "citing_paper_authors": citingPaperAuthors,
            "cluster_id": clusterId,
            "scholar_id": scholarId
        ]
        
        // 创建通知请求
        let identifier = "new_citation_\(clusterId)_\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // 立即显示
        )
        
        // 发送通知
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ [CitationChangeNotification] Notification sent: \(body)")
        } catch {
            print("❌ [CitationChangeNotification] Failed to send notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// 初始化学者的引用量记录（用于首次加载）
    public func initializeCitationCounts(for scholarId: String) {
        guard let publications = UnifiedCacheManager.shared.getPublications(
            scholarId: scholarId,
            sortBy: "total",
            startIndex: 0,
            limit: 100
        ) else {
            return
        }
        
        var counts: [String: Int] = [:]
        for publication in publications {
            if let clusterId = publication.clusterId,
               let citationCount = publication.citationCount {
                counts[clusterId] = citationCount
            }
        }
        
        previousCitationCounts[scholarId] = counts
        print("🔔 [CitationChangeNotification] Initialized citation counts for \(scholarId): \(counts.count) publications")
    }
    
    /// 清除学者的引用量记录
    public func clearCitationCounts(for scholarId: String) {
        previousCitationCounts.removeValue(forKey: scholarId)
        print("🔔 [CitationChangeNotification] Cleared citation counts for \(scholarId)")
    }
    
    // MARK: - Test Methods
    
    /// 测试：发送一个示例通知
    public func sendTestNotification() async {
        await sendNewCitationNotification(
            publicationTitle: "Deep Learning for Natural Language Processing",
            citingPaperTitle: "Transformer Models in Modern NLP: A Comprehensive Survey",
            citingPaperAuthors: "Smith, J., Johnson, M., et al.",
            clusterId: "test_cluster_123",
            scholarId: "test_scholar_456"
        )
    }
}

