# Google Scholar 访问管理分析

## 当前状况：❌ 不是所有访问都通过同一个 fetch 管理

### 问题总结

目前存在**多个访问路径**，有些通过协调器统一管理，有些直接调用服务，导致：

1. **无法统一控制速率限制**
2. **无法统一管理任务队列**
3. **可能触发反爬虫机制**
4. **缓存策略不一致**

---

## 访问路径分析

### ✅ 通过协调器管理（推荐方式）

#### 1. Dashboard 刷新
```
CiteTrackApp.refreshAllScholarsAsync()
  ↓
ScholarDataService.fetchAndUpdateScholarsWithCoordinator()
  ↓
CitationFetchCoordinator.fetchScholarComprehensive() ✅
  ↓
CitationFetchService.fetchScholarPublicationsWithInfo()
```

**状态**: ✅ 已统一管理

---

#### 2. Widget 更新
```
Widget 后台任务
  ↓
ScholarDataService.fetchAndUpdateScholarWithCoordinator()
  ↓
CitationFetchCoordinator.fetchScholarComprehensive() ✅
```

**状态**: ✅ 已统一管理

---

#### 3. Who Cite Me - 论文列表
```
WhoCiteMeView
  ↓
CitationManager.fetchScholarPublications()
  ↓
CitationFetchCoordinator.fetchScholarPublicationsWithPrefetch() ✅
  ↓
CitationFetchService.fetchScholarPublicationsWithInfo()
```

**状态**: ✅ 已统一管理

---

### ❌ 直接调用（绕过协调器）

#### 1. Who Cite Me - 查看引用列表 ⚠️

**位置**: `iOS/CiteTrack/Views/WhoCiteMeView.swift`

**问题代码**:
```swift
// 第775行 - 后台静默更新
CitationFetchService.shared.fetchCitingPapersForClusterId(...) ❌

// 第793行 - 首次加载
CitationFetchService.shared.fetchCitingPapersForClusterId(...) ❌

// 第832行 - 加载更多（后台）
CitationFetchService.shared.fetchCitingPapersForClusterId(...) ❌

// 第853行 - 加载更多
CitationFetchService.shared.fetchCitingPapersForClusterId(...) ❌
```

**应该使用**:
```swift
await CitationFetchCoordinator.shared.fetchCitingPapersWithPrefetch(
    clusterId: clusterId,
    priority: .high
)
```

**影响**: 
- ❌ 绕过速率限制
- ❌ 绕过任务队列
- ❌ 可能触发反爬虫

---

#### 2. Dashboard - 单个学者刷新 ⚠️

**位置**: `iOS/CiteTrack/CiteTrackApp.swift:1370`

**问题代码**:
```swift
private func fetchScholarInfo(for scholar: Scholar) {
    googleScholarService.fetchScholarInfo(for: scholar.id) { ... } ❌
}
```

**应该使用**:
```swift
await CitationFetchCoordinator.shared.fetchScholarComprehensive(
    scholarId: scholar.id,
    priority: .high
)
```

**影响**:
- ❌ 使用旧服务（GoogleScholarService）
- ❌ 绕过协调器
- ❌ 无法批量预取

---

#### 3. Dashboard - 批量刷新（旧代码）⚠️

**位置**: `iOS/CiteTrack/CiteTrackApp.swift:277, 433, 1420, 1476`

**问题代码**:
```swift
GoogleScholarService.shared.fetchScholarInfo(for: scholar.id) { ... } ❌
```

**影响**:
- ❌ 使用旧服务
- ❌ 绕过协调器
- ❌ 无法批量预取

---

#### 4. 自动更新 ⚠️

**位置**: `iOS/CiteTrack/AutoUpdateManager.swift:167`

**问题代码**:
```swift
googleScholarService.fetchScholarInfo(for: scholar.id) { ... } ❌
```

**应该使用**:
```swift
await CitationFetchCoordinator.shared.fetchScholarComprehensive(
    scholarId: scholar.id,
    priority: .medium  // 自动更新使用中等优先级
)
```

**影响**:
- ❌ 使用旧服务
- ❌ 绕过协调器
- ❌ 无法批量预取

---

## 统一管理方案

### 方案 1: 修改所有直接调用（推荐）

#### 修改 WhoCiteMeView.swift

**当前代码** (第775行):
```swift
CitationFetchService.shared.fetchCitingPapersForClusterId(
    clusterId, 
    startIndex: 0, 
    sortByDate: citingPapersSortByDate
) { result in ... }
```

**修改为**:
```swift
Task {
    await CitationFetchCoordinator.shared.fetchCitingPapersWithPrefetch(
        clusterId: clusterId,
        priority: .high
    )
    
    // 从缓存读取数据
    let cachedPapers = CitationCacheService.shared.getCachedCitingPapersList(
        for: clusterId,
        sortByDate: citingPapersSortByDate,
        startIndex: 0
    )
    
    if let papers = cachedPapers {
        DispatchQueue.main.async {
            self.citingPapers = papers
            self.hasMoreCitingPapers = papers.count >= 10
            self.isLoadingCitingPapers = false
        }
    }
}
```

---

#### 修改 CiteTrackApp.swift

**当前代码** (第1370行):
```swift
googleScholarService.fetchScholarInfo(for: scholar.id) { result in ... }
```

**修改为**:
```swift
Task {
    await CitationFetchCoordinator.shared.fetchScholarComprehensive(
        scholarId: scholar.id,
        priority: .high
    )
    
    // 从缓存读取数据
    if let publications = CitationCacheService.shared.getCachedScholarPublicationsList(
        for: scholar.id,
        sortBy: "total",
        startIndex: 0
    ), !publications.isEmpty {
        let totalCitations = publications.reduce(0) { $0 + ($1.citationCount ?? 0) }
        // 更新UI...
    }
}
```

---

#### 修改 AutoUpdateManager.swift

**当前代码** (第167行):
```swift
googleScholarService.fetchScholarInfo(for: scholar.id) { result in ... }
```

**修改为**:
```swift
await CitationFetchCoordinator.shared.fetchScholarComprehensive(
    scholarId: scholar.id,
    priority: .medium  // 自动更新使用中等优先级
)
```

---

### 方案 2: 在协调器中添加包装方法

在 `CitationFetchCoordinator` 中添加兼容方法：

```swift
/// 兼容旧代码：获取学者基本信息（使用协调器）
public func fetchScholarInfo(
    for scholarId: String,
    completion: @escaping (Result<(name: String, citations: Int), Error>) -> Void
) {
    Task {
        await fetchScholarComprehensive(scholarId: scholarId, priority: .high)
        
        // 从缓存读取
        if let publications = cacheService.getCachedScholarPublicationsList(
            for: scholarId,
            sortBy: "total",
            startIndex: 0
        ), !publications.isEmpty {
            let totalCitations = publications.reduce(0) { $0 + ($1.citationCount ?? 0) }
            // 获取学者名字...
            completion(.success((name: "...", citations: totalCitations)))
        } else {
            completion(.failure(NSError(...)))
        }
    }
}
```

---

## 当前访问路径统计

| 访问场景 | 当前方式 | 是否统一管理 | 优先级 |
|---------|---------|------------|--------|
| Dashboard 批量刷新 | 协调器 ✅ | ✅ 是 | 高 |
| Dashboard 单个刷新 | 直接调用 ❌ | ❌ 否 | 高 |
| Widget 更新 | 协调器 ✅ | ✅ 是 | 高 |
| Who Cite Me 论文列表 | 协调器 ✅ | ✅ 是 | 高 |
| Who Cite Me 引用列表 | 直接调用 ❌ | ❌ 否 | 高 |
| 自动更新 | 直接调用 ❌ | ❌ 否 | 中 |

---

## 建议的修改优先级

### 🔴 高优先级（立即修改）

1. **WhoCiteMeView.swift** - 查看引用列表
   - 4处直接调用 `fetchCitingPapersForClusterId()`
   - 影响：可能触发反爬虫

2. **AutoUpdateManager.swift** - 自动更新
   - 使用旧服务，绕过协调器
   - 影响：无法批量预取，效率低

### 🟡 中优先级（尽快修改）

3. **CiteTrackApp.swift** - 单个学者刷新
   - 使用旧服务
   - 影响：功能受限，无法预取

4. **CiteTrackApp.swift** - 批量刷新（旧代码路径）
   - 多处使用旧服务
   - 影响：代码冗余

---

## 统一管理后的优势

### ✅ 统一速率控制
- 所有请求间隔 2-3秒
- 避免触发反爬虫

### ✅ 统一任务队列
- 按优先级排序
- 自动去重
- 智能缓存检查

### ✅ 批量预取
- 一次性获取多种排序方式
- 预取多个页面
- 最大化数据获取

### ✅ 统一缓存策略
- 24小时缓存有效期
- 所有功能共享缓存
- 减少网络请求

---

## 实施步骤

1. **第一步**: 修改 `WhoCiteMeView.swift` 中的引用列表获取
2. **第二步**: 修改 `AutoUpdateManager.swift` 使用协调器
3. **第三步**: 修改 `CiteTrackApp.swift` 中的单个学者刷新
4. **第四步**: 清理旧代码，移除 `GoogleScholarService` 的直接调用
5. **第五步**: 测试所有功能，确保正常工作

---

## 检查清单

- [ ] WhoCiteMeView - 引用列表获取（4处）
- [ ] AutoUpdateManager - 自动更新
- [ ] CiteTrackApp - 单个学者刷新
- [ ] CiteTrackApp - 批量刷新（旧代码）
- [ ] 移除所有 `GoogleScholarService.shared.fetchScholarInfo()` 的直接调用
- [ ] 移除所有 `CitationFetchService.shared.fetchCitingPapersForClusterId()` 的直接调用
- [ ] 测试所有功能
- [ ] 验证速率限制是否生效
- [ ] 验证缓存是否正常工作

