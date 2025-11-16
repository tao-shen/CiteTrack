# 统一缓存架构实施进度

## 已完成任务 ✅

### 任务1: 添加新文件到 Xcode 项目 ✅
- [x] 创建 `UnifiedCacheManager.swift` - 统一缓存管理器
- [x] 创建 `CitationFetchService+ScholarInfo.swift` - 学者信息提取器
- [x] 添加到 Xcode 项目并编译通过

### 任务2: 修改 CitationFetchService ✅
- [x] 创建 `ScholarPublicationsResult` 结构体
- [x] 添加 `fetchScholarPublicationsWithInfo()` 新方法，返回学者完整信息
- [x] 保持旧的 `fetchScholarPublications()` 向后兼容
- [x] 编译测试通过，无错误无警告

## 待实施任务

### 任务3: 修改 CitationFetchCoordinator（下一步）
需要修改 `fetchScholarPublications()` 方法以：
1. 使用新的 `fetchScholarPublicationsWithInfo()` 方法
2. 在成功获取数据后，保存到统一缓存
3. 保持现有的旧缓存逻辑不变（双缓存策略）

代码位置：`Shared/Services/CitationFetchCoordinator.swift:421`

```swift
private func fetchScholarPublications(scholarId: String, sortBy: String, startIndex: Int) async -> Bool {
    return await withCheckedContinuation { continuation in
        // 改用新方法
        fetchService.fetchScholarPublicationsWithInfo(
            for: scholarId,
            sortBy: sortBy,
            startIndex: startIndex,
            forceRefresh: false
        ) { [weak self] result in
            // ...
            case .success(let publicationsResult):
                // 1. 旧缓存（保持兼容）
                self.cacheService.cacheScholarPublicationsList(...)
                
                // 2. 新缓存（统一缓存）
                Task { @MainActor in
                    let snapshot = ScholarDataSnapshot(
                        scholarId: scholarId,
                        scholarName: publicationsResult.scholarInfo?.name,
                        totalCitations: publicationsResult.scholarInfo?.totalCitations,
                        publications: publicationsResult.publications,
                        sortBy: sortBy,
                        startIndex: startIndex,
                        source: .whoCiteMe
                    )
                    UnifiedCacheManager.shared.saveDataSnapshot(snapshot)
                }
        }
    }
}
```

### 任务4: 修改 ScholarDataService
让 Dashboard 刷新时优先从统一缓存获取数据：

```swift
public func fetchAndUpdateScholar(id: String) async throws -> Scholar {
    // 1. 先检查统一缓存
    if let basicInfo = await UnifiedCacheManager.shared.getScholarBasicInfo(scholarId: id) {
        // 使用缓存数据，跳过网络请求
        var scholar = Scholar(id: id, name: basicInfo.name)
        scholar.citations = basicInfo.citations
        scholar.lastUpdated = basicInfo.lastUpdated
        await dataManager.updateScholar(scholar)
        return scholar
    }
    
    // 2. 缓存未命中，使用原有逻辑获取数据
    let (name, citations) = try await fetchScholarInfo(for: id)
    // ...
}
```

### 任务5: 修改 CitationManager
订阅统一缓存的数据变化事件：

```swift
private var cacheSubscription: AnyCancellable?

private init() {
    // ...
    
    // 订阅统一缓存的数据变化
    Task { @MainActor in
        cacheSubscription = UnifiedCacheManager.shared.dataChangePublisher
            .sink { [weak self] event in
                self?.handleCacheChange(event)
            }
    }
}

private func handleCacheChange(_ event: UnifiedCacheManager.DataChangeEvent) {
    switch event {
    case .scholarInfoUpdated(let scholarId, let oldCitations, let newCitations):
        print("📢 Scholar \(scholarId) citations updated: \(oldCitations ?? 0) -> \(newCitations ?? 0)")
        // 通知 UI 更新
        
    case .publicationsUpdated(let scholarId, let sortBy, let count):
        print("📢 Publications updated for \(scholarId): \(count) items, sortBy: \(sortBy)")
        // 刷新 Who Cite Me 等模块
    }
}
```

## 核心优势

1. **最大化数据利用**：
   - Dashboard 刷新 → 自动更新 Who Cite Me 的论文列表
   - Who Cite Me 加载 → 使用 Dashboard 已获取的数据
   
2. **减少网络请求**：
   - 一次访问 Google Scholar，多处使用数据
   - 避免重复请求相同的内容

3. **数据一致性**：
   - 所有模块看到的都是同一份最新数据
   - 自动检测引用数变化

## 测试场景

### 场景1：Dashboard 刷新后，Who Cite Me 自动更新
1. 打开 Dashboard
2. 点击刷新学者数据
3. 打开 Who Cite Me
4. 验证：论文列表已经是最新的，无需额外请求

### 场景2：Who Cite Me 首次加载，使用 Dashboard 的缓存
1. 打开 Dashboard（已有缓存的学者数据）
2. 打开 Who Cite Me
3. 验证：立即显示论文列表，使用 Dashboard 的缓存数据

### 场景3：引用数变化检测
1. 刷新学者数据
2. 如果引用数有变化
3. 验证：Dashboard 和 Who Cite Me 都收到通知并更新

## 注意事项

- **渐进式实施**：每完成一个任务都编译测试
- **保持兼容性**：旧的缓存逻辑保持不变，新旧双缓存并行
- **错误处理**：统一缓存失败不影响现有功能
- **性能优化**：使用 @MainActor 确保 UI 更新在主线程

