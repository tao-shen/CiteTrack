# 基于页面类型的 Fetch 统一管理

## 设计理念

**按照 Google Scholar 页面种类来组织 Fetch 方法，并根据不同页面上获取的内容进行统一管理**

---

## 页面类型定义

### GoogleScholarPageType 枚举

```swift
public enum GoogleScholarPageType {
    case scholarProfile(scholarId: String, sortBy: String?, startIndex: Int)  // 学者主页
    case citedBy(clusterId: String, sortByDate: Bool, startIndex: Int)        // 引用页面
    case paperDetail(paperId: String)                                        // 论文详情页（保留）
    case authorSearch(authorName: String)                                     // 作者搜索页（保留）
}
```

**每个页面类型包含**:
- 页面标识符 (`identifier`) - 用于缓存和去重
- 页面URL (`url`) - 用于访问
- 提取内容类型 (`extractedContentType`) - 说明能获取什么内容

---

## 页面类型 → Fetch 方法 → 提取内容 → 缓存管理

### 1. 学者主页 (Scholar Profile Page)

**页面类型**: `scholarProfile`

**Fetch 方法**:
```swift
fetchScholarProfilePage(
    scholarId: String,
    sortBy: String = "total",
    startIndex: Int = 0,
    priority: FetchPriority = .high
) async -> Bool
```

**提取内容**:
- **学者基本信息** (仅第一页):
  - 姓名 (`name`)
  - 总引用数 (`totalCitations`)
  - h-index (`hIndex`)
  - i10-index (`i10Index`)
- **论文列表** (每页最多100篇):
  - 标题 (`title`)
  - Cluster ID (`clusterId`)
  - 引用数 (`citationCount`)
  - 年份 (`year`)

**缓存管理**:
```swift
// 1. 学者信息 → UnifiedCacheManager
UnifiedCacheManager.shared.saveDataSnapshot(snapshot)
// 缓存键: scholarId
// 缓存位置: scholarBasicInfo[scholarId]

// 2. 论文列表 → UnifiedCacheManager + CitationCacheService
// 统一缓存
UnifiedCacheManager.shared.saveDataSnapshot(snapshot)
// 缓存键: scholarId -> sortBy -> [ScholarPublication]

// 旧缓存（兼容性）
cacheService.cacheScholarPublicationsList(...)
// 缓存键: "{scholarId}_{sortBy}_{startIndex}"
```

**使用场景**:
- Dashboard 刷新
- Widget 更新
- Who Cite Me 论文列表
- 自动更新

---

### 2. 引用页面 (Cited By Page)

**页面类型**: `citedBy`

**Fetch 方法**:
```swift
fetchCitedByPage(
    clusterId: String,
    sortByDate: Bool = true,
    startIndex: Int = 0,
    priority: FetchPriority = .high
) async -> Bool
```

**提取内容**:
- **引用论文列表** (每页最多10篇):
  - 标题 (`title`)
  - 作者列表 (`authors`)
  - 年份 (`year`)
  - 发表场所 (`venue`)
  - 引用数 (`citationCount`)
  - 摘要 (`abstract`)
  - Google Scholar 链接 (`scholarUrl`)
  - PDF 链接 (`pdfUrl`)

**缓存管理**:
```swift
// 引用论文 → CitationCacheService
cacheService.cacheCitingPapersList(papers, ...)
// 缓存键: "{clusterId}_{sortByDate}_{startIndex}"
// 缓存位置: citingPapersCache[key]
```

**使用场景**:
- Who Cite Me 查看引用

---

### 3. 论文详情页 (Paper Detail Page) - 保留

**页面类型**: `paperDetail`

**状态**: 代码中有定义，但未实现 fetch 方法

**计划提取内容**:
- 论文详细信息
- 完整作者列表
- 完整摘要
- 相关论文

---

### 4. 作者搜索页 (Author Search Page) - 保留

**页面类型**: `authorSearch`

**状态**: 代码中有定义，但未实现 fetch 方法

**计划提取内容**:
- 作者基本信息
- 机构信息
- 研究兴趣
- 引用统计

---

## 高级 Fetch 方法（组合多个页面访问）

### fetchScholarComprehensive()

**功能**: 全面刷新学者数据

**内部实现**:
```swift
// 1. 访问学者主页（第一页，获取基本信息）
await fetchScholarProfilePage(scholarId: scholarId, sortBy: "total", startIndex: 0)

// 2. 访问学者主页（其他排序的第一页）
for sortBy in ["pubdate", "title"] {
    addTask(.scholarProfile(scholarId: scholarId, sortBy: sortBy, startIndex: 0))
}

// 3. 预取后续页面
for sortBy in ["total", "pubdate", "title"] {
    for page in 1..<3 {
        addTask(.scholarProfile(scholarId: scholarId, sortBy: sortBy, startIndex: page * 100))
    }
}
```

**访问页面**: 学者主页（最多10次）

**提取内容**: 学者信息 + 论文列表（3种排序 × 3页）

---

### fetchScholarPublicationsWithPrefetch()

**功能**: 获取学者论文列表（带预取）

**内部实现**:
```swift
// 1. 访问学者主页（当前排序的第一页）
await fetchScholarProfilePage(scholarId: scholarId, sortBy: sortBy, startIndex: 0)

// 2. 预取其他排序和页面
if !onlyFirstPage {
    // 其他排序的第一页
    // 后续页面
}
```

**访问页面**: 学者主页（1-9次）

---

### fetchCitingPapersWithPrefetch()

**功能**: 获取引用论文列表（带预取）

**内部实现**:
```swift
// 1. 访问引用页面（两种排序的第一页）
await fetchCitedByPage(clusterId: clusterId, sortByDate: true, startIndex: 0)
addTask(.citedBy(clusterId: clusterId, sortByDate: false, startIndex: 0))

// 2. 预取后续页面
for sortByDate in [true, false] {
    for page in 1..<2 {
        addTask(.citedBy(clusterId: clusterId, sortByDate: sortByDate, startIndex: page * 10))
    }
}
```

**访问页面**: 引用页面（最多4次）

---

## 缓存管理策略

### 按页面类型管理缓存

#### 学者主页缓存

**缓存键结构**:
```
学者信息: scholarId
论文列表: "{scholarId}_{sortBy}_{startIndex}"
```

**缓存位置**:
1. `UnifiedCacheManager.scholarBasicInfo[scholarId]` - 学者信息
2. `UnifiedCacheManager.scholarPublications[scholarId][sortBy]` - 论文列表（统一格式）
3. `CitationCacheService.scholarPublicationsCache[key]` - 论文列表（旧格式，兼容性）

**更新时机**:
- `fetchScholarProfilePageContent()` 成功后
- 自动保存到统一缓存和旧缓存

---

#### 引用页面缓存

**缓存键结构**:
```
"{clusterId}_{sortByDate}_{startIndex}"
```

**缓存位置**:
- `CitationCacheService.citingPapersCache[key]`

**更新时机**:
- `fetchCitedByPageContent()` 成功后

---

## 任务队列管理

### FetchTaskType（基于页面类型）

```swift
enum FetchTaskType: Hashable {
    case scholarProfile(scholarId: String, sortBy: String, startIndex: Int)
    case citedBy(clusterId: String, sortByDate: Bool, startIndex: Int)
    
    var pageType: GoogleScholarPageType { ... }
    var identifier: String { ... }
}
```

**特点**:
- 每个任务类型对应一个页面类型
- 自动生成页面标识符
- 支持缓存检查

---

## 使用示例

### 访问学者主页

```swift
// 方式1: 直接访问单页
await CitationFetchCoordinator.shared.fetchScholarProfilePage(
    scholarId: "kukA0LcAAAAJ",
    sortBy: "total",
    startIndex: 0
)

// 方式2: 全面刷新（内部调用 fetchScholarProfilePage）
await CitationFetchCoordinator.shared.fetchScholarComprehensive(
    scholarId: "kukA0LcAAAAJ"
)
```

### 访问引用页面

```swift
// 方式1: 直接访问单页
await CitationFetchCoordinator.shared.fetchCitedByPage(
    clusterId: "123456789",
    sortByDate: true,
    startIndex: 0
)

// 方式2: 带预取（内部调用 fetchCitedByPage）
await CitationFetchCoordinator.shared.fetchCitingPapersWithPrefetch(
    clusterId: "123456789"
)
```

---

## 优势

### 1. 清晰的页面类型映射
- 每个页面类型对应一个 fetch 方法
- 页面类型包含 URL 和标识符
- 易于扩展新页面类型

### 2. 统一的内容管理
- 每个页面类型明确提取什么内容
- 缓存管理按页面类型组织
- 数据流向清晰

### 3. 易于维护
- 页面类型和 fetch 方法一一对应
- 修改页面访问逻辑只需修改对应方法
- 添加新页面类型只需添加新的 case

### 4. 类型安全
- 使用枚举定义页面类型
- 编译时检查页面参数
- 避免 URL 构建错误

---

## 总结

**核心原则**:
1. **页面类型 = Fetch 方法类型**
2. **每个页面类型对应一个 fetch 方法**
3. **根据页面提取的内容进行缓存管理**
4. **高级方法组合多个页面访问**

**页面类型 → Fetch → 内容 → 缓存** 的完整映射关系已建立，实现了统一管理。

