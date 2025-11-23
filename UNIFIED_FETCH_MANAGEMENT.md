# Google Scholar 统一 Fetch 管理文档

## 目录
1. [Google Scholar 页面类型](#google-scholar-页面类型)
2. [Fetch 方法映射](#fetch-方法映射)
3. [页面内容提取](#页面内容提取)
4. [iOS 功能使用映射](#ios-功能使用映射)
5. [本地缓存更新](#本地缓存更新)
6. [统一管理策略](#统一管理策略)

---

## Google Scholar 页面类型

### 1. 学者主页 (Scholar Profile Page)

**URL 模式**:
```
https://scholar.google.com/citations?user={scholarId}&hl=en&cstart={startIndex}&pagesize=100&sortby={sortBy}
```

**参数说明**:
- `user`: 学者ID（必需）
- `cstart`: 分页起始索引（0, 100, 200...）
- `pagesize`: 每页数量（固定100）
- `sortby`: 排序方式
  - `total` - 按引用数排序
  - `pubdate` - 按发表日期排序
  - `title` - 按标题排序

**页面特点**:
- 第一页包含学者基本信息
- 每页最多100篇论文
- 支持3种排序方式

---

### 2. 引用页面 (Cited By Page)

**URL 模式**:
```
https://scholar.google.com/scholar?hl=en&cites={clusterId}&scisbd={1|0}&start={startIndex}
```

**参数说明**:
- `cites`: 论文的 cluster ID（必需）
- `scisbd`: 排序方式
  - `1` - 按日期排序
  - `0` 或不设置 - 按相关性排序
- `start`: 分页起始索引（0, 10, 20...）

**页面特点**:
- 每页最多10篇引用论文
- 支持2种排序方式

---

### 3. 论文详情页 (Paper Detail Page) - 保留接口

**URL 模式**:
```
https://scholar.google.com/scholar?hl=en&cluster={paperId}
```

**状态**: 代码中有，但未使用

---

### 4. 作者搜索页 (Author Search Page) - 保留接口

**URL 模式**:
```
https://scholar.google.com/citations?hl=en&view_op=search_authors&mauthors={authorName}
```

**状态**: 代码中有，但未使用

---

## Fetch 方法映射

### CitationFetchService (底层网络层)

#### 1. `fetchScholarPublicationsWithInfo()`
**访问页面**: 学者主页

**URL 构建**: `buildScholarProfileURL()`

**提取内容**:
- 学者基本信息（仅第一页）:
  - 姓名
  - 总引用数
  - h-index
  - i10-index
- 论文列表:
  - 标题
  - Cluster ID
  - 引用数
  - 年份

**返回类型**: `ScholarPublicationsResult`

---

#### 2. `fetchCitingPapersForClusterId()`
**访问页面**: 引用页面

**URL 构建**: `buildCitedByURL()`

**提取内容**:
- 引用论文列表:
  - 标题
  - 作者列表
  - 年份
  - 发表场所
  - 引用数
  - 摘要
  - Google Scholar 链接
  - PDF 链接

**返回类型**: `[CitingPaper]`

---

#### 3. `fetchPaperDetails()` - 保留接口
**访问页面**: 论文详情页

**URL 构建**: `buildPaperDetailURL()`

**状态**: 未使用

---

#### 4. `fetchAuthorDetails()` - 保留接口
**访问页面**: 作者搜索页

**URL 构建**: `buildAuthorSearchURL()`

**状态**: 未使用

---

### CitationFetchCoordinator (协调器层)

#### 1. `fetchScholarComprehensive()`
**内部调用**: `fetchScholarPublicationsWithInfo()`

**访问页面**: 学者主页（多次访问）

**访问次数**: 
- 1次基本信息
- 3次论文列表（3种排序的第一页）
- 6次预取（3种排序 × 2页）

**总计**: 最多10次访问

---

#### 2. `fetchScholarPublicationsWithPrefetch()`
**内部调用**: `fetchScholarPublicationsWithInfo()`

**访问页面**: 学者主页

**访问次数**:
- 1次当前排序的第一页（高优先级）
- 2次其他排序的第一页（中优先级）
- 6次预取（3种排序 × 2页）

**总计**: 最多9次访问

---

#### 3. `fetchCitingPapersWithPrefetch()`
**内部调用**: `fetchCitingPapersForClusterId()`

**访问页面**: 引用页面

**访问次数**:
- 2次第一页（2种排序，高优先级）
- 2次预取（2种排序 × 1页，低优先级）

**总计**: 最多4次访问

---

## 页面内容提取

### 学者主页提取内容

#### 学者基本信息（仅第一页）
```swift
struct ScholarFullInfo {
    let name: String              // 学者姓名
    let totalCitations: Int       // 总引用数
    let hIndex: Int?              // h-index
    let i10Index: Int?           // i10-index
}
```

**提取方法**: `extractScholarFullInfo()`

---

#### 论文列表（每页最多100篇）
```swift
struct ScholarPublication {
    let id: String                // UUID 或 clusterId
    let title: String             // 论文标题
    let clusterId: String?        // Cluster ID（用于查看引用）
    let citationCount: Int?       // 引用数
    let year: Int?                // 发表年份
}
```

**提取方法**: `parseScholarPublications()`

---

### 引用页面提取内容

#### 引用论文列表（每页最多10篇）
```swift
struct CitingPaper {
    let id: String                // 论文ID
    let title: String             // 标题
    let authors: [String]         // 作者列表
    let year: Int?                // 年份
    let venue: String?            // 发表场所
    let citationCount: Int?       // 引用数
    let abstract: String?         // 摘要
    let scholarUrl: String?       // Google Scholar 链接
    let pdfUrl: String?           // PDF 链接
    let citedScholarId: String    // 被引用的学者ID
    let fetchedAt: Date           // 获取时间
}
```

**提取方法**: `parseCitingPapersHTML()`

---

## iOS 功能使用映射

### Dashboard (主页面)

**使用的 Fetch**:
```swift
CitationFetchCoordinator.fetchScholarComprehensive(
    scholarId: String,
    priority: .high
)
```

**访问页面**: 学者主页（10次）

**触发场景**:
- 用户下拉刷新
- 点击"更新全部"按钮
- Widget 后台更新
- 自动更新

**获取内容**:
- 学者基本信息
- 论文列表（3种排序 × 3页）

---

### Who Cite Me - 论文列表

**使用的 Fetch**:
```swift
CitationFetchCoordinator.fetchScholarPublicationsWithPrefetch(
    scholarId: String,
    sortBy: String,
    priority: .high,
    onlyFirstPage: Bool
)
```

**访问页面**: 学者主页（1-9次）

**触发场景**:
- 首次加载论文列表
- 切换排序方式
- 加载更多论文

**获取内容**:
- 论文列表（按选择的排序方式）

**注意**: 
- `onlyFirstPage=true`: 只访问1次（立即显示）
- `onlyFirstPage=false`: 访问最多9次（包含预取）

---

### Who Cite Me - 查看引用

**当前问题**: 直接调用 `CitationFetchService.fetchCitingPapersForClusterId()` ❌

**应该使用**:
```swift
CitationFetchCoordinator.fetchCitingPapersWithPrefetch(
    clusterId: String,
    priority: .high
)
```

**访问页面**: 引用页面（最多4次）

**触发场景**:
- 用户点击论文，查看引用列表
- 加载更多引用论文

**获取内容**:
- 引用论文列表（2种排序）

---

### Widget 更新

**使用的 Fetch**:
```swift
CitationFetchCoordinator.fetchScholarComprehensive(
    scholarId: String,
    priority: .high
)
```

**访问页面**: 学者主页（10次）

**触发场景**:
- Widget 定时刷新
- 用户点击 Widget 刷新按钮

**获取内容**:
- 学者基本信息
- 论文列表

---

### 自动更新

**当前问题**: 直接调用 `GoogleScholarService.fetchScholarInfo()` ❌

**应该使用**:
```swift
CitationFetchCoordinator.fetchScholarComprehensive(
    scholarId: String,
    priority: .medium
)
```

**访问页面**: 学者主页（10次）

**触发场景**:
- 定时自动更新所有学者

**获取内容**:
- 学者基本信息
- 论文列表

---

## 本地缓存更新

### CitationCacheService (内存缓存)

#### 1. 学者论文列表缓存

**缓存键**: `"{scholarId}_{sortBy}_{startIndex}"`

**示例**: `"kukA0LcAAAAJ_total_0"`

**更新时机**: 
- `fetchScholarPublicationsWithInfo()` 成功后

**缓存内容**:
```swift
[String: (publications: [ScholarPublication], timestamp: Date)]
```

**过期时间**: 24小时

**更新方法**:
```swift
cacheService.cacheScholarPublicationsList(
    publications,
    for: scholarId,
    sortBy: sortBy,
    startIndex: startIndex
)
```

---

#### 2. 引用论文列表缓存

**缓存键**: `"{clusterId}_{sortByDate}_{startIndex}"`

**示例**: `"123456789_true_0"`

**更新时机**:
- `fetchCitingPapersForClusterId()` 成功后

**缓存内容**:
```swift
[String: (papers: [CitingPaper], timestamp: Date)]
```

**过期时间**: 24小时

**更新方法**:
```swift
cacheService.cacheCitingPapersList(
    papers,
    for: clusterId,
    sortByDate: sortByDate,
    startIndex: startIndex
)
```

---

### UnifiedCacheManager (统一缓存管理器)

#### 1. 学者基本信息缓存

**缓存键**: `scholarId`

**更新时机**:
- `fetchScholarPublicationsWithInfo()` 返回学者信息时

**缓存内容**:
```swift
[String: ScholarBasicInfo]

struct ScholarBasicInfo {
    let scholarId: String
    let name: String
    let citations: Int
    let hIndex: Int?
    let i10Index: Int?
    let lastUpdated: Date
    let source: DataSource
}
```

**更新方法**:
```swift
UnifiedCacheManager.shared.saveDataSnapshot(snapshot)
```

---

#### 2. 论文列表缓存（统一格式）

**缓存键**: `scholarId -> sortBy -> [ScholarPublication]`

**更新时机**:
- `fetchScholarPublicationsWithInfo()` 成功后

**缓存内容**:
```swift
[String: [String: [ScholarPublication]]]
```

**更新方法**:
```swift
UnifiedCacheManager.shared.saveDataSnapshot(snapshot)
```

---

#### 3. 引用论文缓存（统一格式）

**缓存键**: `clusterId -> sortByDate -> [CitingPaper]`

**更新时机**:
- `fetchCitingPapersForClusterId()` 成功后

**缓存内容**:
```swift
[String: [String: [CitingPaper]]]
```

**更新方法**:
```swift
UnifiedCacheManager.shared.saveDataSnapshot(snapshot)
```

---

### 持久化存储

**存储位置**: UserDefaults (App Group)

**存储键**: `"UnifiedCacheManager_Data"`

**存储内容**:
- 学者基本信息
- 论文列表
- 引用论文列表
- 最后保存时间

**更新时机**: 
- 每次 `saveDataSnapshot()` 后自动持久化

---

## 统一管理策略

### 访问控制

#### 1. 所有访问必须通过协调器

**禁止**:
```swift
// ❌ 禁止直接调用
CitationFetchService.shared.fetchScholarPublicationsWithInfo(...)
CitationFetchService.shared.fetchCitingPapersForClusterId(...)
GoogleScholarService.shared.fetchScholarInfo(...)
```

**推荐**:
```swift
// ✅ 通过协调器调用
await CitationFetchCoordinator.shared.fetchScholarComprehensive(...)
await CitationFetchCoordinator.shared.fetchScholarPublicationsWithPrefetch(...)
await CitationFetchCoordinator.fetchCitingPapersWithPrefetch(...)
```

---

#### 2. 速率限制

**配置**:
- 最小间隔: 2秒
- 最大间隔: 3秒
- 随机延迟: 0-0.5秒

**实现位置**: `CitationFetchCoordinator.processQueue()`

**效果**: 所有请求自动间隔 2-3秒

---

#### 3. 任务队列管理

**优先级系统**:
- `high` (3) - 用户主动请求
- `medium` (2) - 预取可能需要的数据
- `low` (1) - 后台批量获取

**去重检查**:
- 检查任务是否已处理
- 检查任务是否已在队列中
- 检查数据是否已缓存

**实现位置**: `CitationFetchCoordinator.addTask()`

---

#### 4. 缓存优先策略

**检查顺序**:
1. 检查统一缓存 (`UnifiedCacheManager`)
2. 检查旧缓存 (`CitationCacheService`)
3. 如果缓存不存在或过期，才发起网络请求

**实现位置**: 
- `CitationFetchCoordinator.isCached()`
- `CitationManager.fetchScholarPublications()`

---

### 数据流管理

#### 完整数据流

```
iOS 功能
  ↓
CitationFetchCoordinator (统一入口)
  ↓
任务队列管理
  - 优先级排序
  - 去重检查
  - 缓存检查
  ↓
CitationFetchService (网络请求)
  ↓
Google Scholar 页面
  ↓
HTML 解析
  ↓
数据提取
  ↓
缓存更新
  - CitationCacheService (内存)
  - UnifiedCacheManager (统一缓存)
  - UserDefaults (持久化)
  ↓
UI 更新
```

---

### 修改清单

#### 需要修改的代码

1. **WhoCiteMeView.swift** (4处)
   - 第775行: `fetchCitingPapersForClusterId()` → `fetchCitingPapersWithPrefetch()`
   - 第793行: `fetchCitingPapersForClusterId()` → `fetchCitingPapersWithPrefetch()`
   - 第832行: `fetchCitingPapersForClusterId()` → `fetchCitingPapersWithPrefetch()`
   - 第853行: `fetchCitingPapersForClusterId()` → `fetchCitingPapersWithPrefetch()`

2. **AutoUpdateManager.swift** (1处)
   - 第167行: `GoogleScholarService.fetchScholarInfo()` → `fetchScholarComprehensive()`

3. **CiteTrackApp.swift** (多处)
   - 第1370行: `GoogleScholarService.fetchScholarInfo()` → `fetchScholarComprehensive()`
   - 第277行, 433行, 1420行, 1476行: 旧代码路径

---

### 统一管理检查清单

- [ ] 所有 Google Scholar 访问都通过 `CitationFetchCoordinator`
- [ ] 没有直接调用 `CitationFetchService` 的方法
- [ ] 没有直接调用 `GoogleScholarService` 的方法
- [ ] 所有数据都保存到统一缓存 (`UnifiedCacheManager`)
- [ ] 速率限制生效（2-3秒间隔）
- [ ] 任务队列正常工作
- [ ] 缓存检查正常工作
- [ ] 持久化存储正常工作

---

## 总结

### 页面 → Fetch → 内容 → 缓存 映射表

| 页面 | Fetch 方法 | 提取内容 | 缓存位置 | 使用场景 |
|------|-----------|---------|---------|---------|
| 学者主页 | `fetchScholarComprehensive()` | 学者信息 + 论文列表 | `UnifiedCacheManager` + `CitationCacheService` | Dashboard, Widget, AutoUpdate |
| 学者主页 | `fetchScholarPublicationsWithPrefetch()` | 论文列表 | `UnifiedCacheManager` + `CitationCacheService` | Who Cite Me |
| 引用页面 | `fetchCitingPapersWithPrefetch()` | 引用论文列表 | `CitationCacheService` | Who Cite Me (查看引用) |

### 关键原则

1. **统一入口**: 所有访问通过 `CitationFetchCoordinator`
2. **速率控制**: 自动间隔 2-3秒
3. **缓存优先**: 先查缓存，再请求
4. **批量预取**: 最大化数据获取
5. **持久化**: 自动保存到本地

