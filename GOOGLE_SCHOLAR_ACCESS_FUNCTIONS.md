# 访问 Google Scholar 的函数和页面映射

## 核心网络请求函数

### 1. CitationFetchService (底层网络请求层)

这些函数直接发送 HTTP 请求到 Google Scholar：

#### 1.1 `fetchScholarPublicationsWithInfo()`
**位置**: `Shared/Services/CitationFetchService.swift:256`

**访问的 URL**:
```
https://scholar.google.com/citations?user={scholarId}&hl=en&cstart={startIndex}&pagesize=100&sortby={sortBy}
```

**功能**: 获取学者的论文列表和基本信息

**被调用位置**:
- `CitationFetchCoordinator.fetchScholarPublications()` (内部调用)
- `CitationFetchCoordinator.fetchScholarBasicInfo()` (内部调用)

---

#### 1.2 `fetchCitingPapersForClusterId()`
**位置**: `Shared/Services/CitationFetchService.swift:187`

**访问的 URL**:
```
https://scholar.google.com/scholar?hl=en&cites={clusterId}&scisbd={1|0}&start={startIndex}
```

**功能**: 获取某篇论文的引用列表

**被调用位置**:
- `CitationFetchCoordinator.fetchCitingPapers()` (内部调用)
- `WhoCiteMeView.swift:775, 793, 832, 853` (直接调用，查看论文引用)

---

#### 1.3 `fetchScholarPublications()` (旧版本，向后兼容)
**位置**: `Shared/Services/CitationFetchService.swift:357`

**访问的 URL**: 同 `fetchScholarPublicationsWithInfo()`

**功能**: 获取学者论文列表（不包含学者信息）

**被调用位置**:
- `CitationFetchService.fetchCitingPapers()` (内部调用)

---

#### 1.4 `fetchCitingPapers()`
**位置**: `Shared/Services/CitationFetchService.swift:151`

**访问的 URL**: 
- 先调用 `fetchScholarPublications()` 获取论文列表
- 然后为每篇论文调用 `fetchCitingPapersForClusterId()`

**功能**: 获取学者的所有引用论文

**被调用位置**:
- `CitationFetchService.fetchCitingAuthors()` (内部调用)

---

#### 1.5 `fetchCitingAuthors()`
**位置**: `Shared/Services/CitationFetchService.swift:497`

**访问的 URL**: 通过 `fetchCitingPapers()` 间接访问

**功能**: 获取引用作者列表

**被调用位置**: 暂无直接调用（保留接口）

---

#### 1.6 `fetchAuthorDetails()`
**位置**: `Shared/Services/CitationFetchService.swift:569`

**访问的 URL**:
```
https://scholar.google.com/citations?hl=en&view_op=search_authors&mauthors={authorName}
```

**功能**: 获取作者详细信息

**被调用位置**: 暂无直接调用（保留接口）

---

#### 1.7 `fetchPaperDetails()`
**位置**: `Shared/Services/CitationFetchService.swift:787`

**访问的 URL**:
```
https://scholar.google.com/scholar?hl=en&cluster={paperId}
```

**功能**: 获取论文详细信息

**被调用位置**: 暂无直接调用（保留接口）

---

### 2. GoogleScholarService (旧服务，部分仍在使用)

#### 2.1 `fetchScholarInfo()`
**位置**: `Shared/Services/GoogleScholarService.swift:55`

**访问的 URL**:
```
https://scholar.google.com/citations?user={scholarId}&hl=en
```

**功能**: 获取学者基本信息（姓名和引用数）

**被调用位置**:
- `AutoUpdateManager.swift` (自动更新时)
- `ScholarDataService.swift` (旧版本数据服务)

---

### 3. ScholarDataService (数据服务层)

#### 3.1 `fetchScholarInfo()` (私有方法)
**位置**: `Shared/Services/ScholarDataService.swift:166`

**访问的 URL**: 同 `GoogleScholarService.fetchScholarInfo()`

**功能**: 获取学者信息（内部使用）

**被调用位置**:
- `ScholarDataService.fetchAndUpdateScholar()` (内部调用)

---

## 协调器层函数 (CitationFetchCoordinator)

这些函数通过任务队列管理，最终调用 `CitationFetchService` 的方法：

### 3.1 `fetchScholarComprehensive()`
**位置**: `Shared/Services/CitationFetchCoordinator.swift:88`

**功能**: 全面刷新学者数据（一次性获取所有信息）

**内部调用**:
- `fetchScholarBasicInfo()` → `fetchScholarPublicationsWithInfo()`
- `fetchScholarPublications()` → `fetchScholarPublicationsWithInfo()`

**被调用的页面**:
1. **Dashboard (主页面)** - `CiteTrackApp.swift:refreshAllScholarsAsync()`
   - 用户下拉刷新时
   - 点击"更新全部"按钮时

2. **Widget 更新** - `CiteTrackWidget.swift` (通过后台任务)
   - Widget 定时刷新时
   - 用户点击 Widget 刷新按钮时

3. **自动更新** - `AutoUpdateManager.swift:performAutoUpdate()`
   - 定时自动更新所有学者数据

4. **ScholarDataService** - `ScholarDataService+Coordinator.swift:13, 65`
   - `fetchAndUpdateScholarWithCoordinator()` - 更新单个学者
   - `fetchAndUpdateScholarsWithCoordinator()` - 批量更新多个学者

---

### 3.2 `fetchScholarPublicationsWithPrefetch()`
**位置**: `Shared/Services/CitationFetchCoordinator.swift:122`

**功能**: 获取学者论文列表（带预取）

**内部调用**:
- `fetchScholarPublications()` → `fetchScholarPublicationsWithInfo()`

**被调用的页面**:
1. **Who Cite Me 页面** - `WhoCiteMeView.swift` (通过 `CitationManager`)
   - 首次加载论文列表时
   - 切换排序方式时（如果缓存不存在）
   - 加载更多论文时

**调用链**:
```
WhoCiteMeView 
  → CitationManager.fetchScholarPublications()
    → CitationFetchCoordinator.fetchScholarPublicationsWithPrefetch()
      → CitationFetchService.fetchScholarPublicationsWithInfo()
```

---

### 3.3 `fetchCitingPapersWithPrefetch()`
**位置**: `Shared/Services/CitationFetchCoordinator.swift:239`

**功能**: 获取引用论文列表（带预取）

**内部调用**:
- `fetchCitingPapers()` → `fetchCitingPapersForClusterId()`

**被调用的页面**:
1. **Who Cite Me 页面** - `WhoCiteMeView.swift` (查看论文引用时)
   - 点击论文，查看引用列表时
   - 加载更多引用论文时

**注意**: 目前 `WhoCiteMeView` 直接调用 `CitationFetchService.fetchCitingPapersForClusterId()`，未使用协调器

---

### 3.4 `prefetchOtherPages()`
**位置**: `Shared/Services/CitationFetchCoordinator.swift:164`

**功能**: 预取当前排序方式的其他页面

**内部调用**:
- `fetchScholarPublications()` → `fetchScholarPublicationsWithInfo()`

**被调用的页面**:
1. **Who Cite Me 页面** - `CitationManager.swift:196` (后台预取)
   - 首次加载第一页后，后台预取后续页面

---

## 页面调用映射表

| 页面/功能 | 调用的函数 | 访问的 Google Scholar 页面 |
|---------|----------|-------------------------|
| **Dashboard (主页面)** | `fetchScholarComprehensive()` | 学者主页 (`/citations?user=...`) |
| | | - 基本信息 |
| | | - 论文列表（3种排序 × 3页） |
| **Who Cite Me** | `fetchScholarPublicationsWithPrefetch()` | 学者主页 (`/citations?user=...`) |
| | | - 论文列表（按选择的排序） |
| **Who Cite Me (查看引用)** | `fetchCitingPapersForClusterId()` | 引用页面 (`/scholar?cites=...`) |
| | | - 某篇论文的引用列表 |
| **Widget** | `fetchScholarComprehensive()` | 学者主页 (`/citations?user=...`) |
| | | - 基本信息 |
| | | - 论文列表 |
| **自动更新** | `fetchScholarComprehensive()` | 学者主页 (`/citations?user=...`) |
| | | - 所有学者的数据 |

---

## URL 模式总结

### 1. 学者主页
```
https://scholar.google.com/citations?user={scholarId}&hl=en&cstart={startIndex}&pagesize=100&sortby={sortBy}
```

**参数说明**:
- `user`: 学者ID
- `cstart`: 起始索引（分页）
- `pagesize`: 每页数量（固定100）
- `sortby`: 排序方式 (`total`, `pubdate`, `title`)

**访问此URL的函数**:
- `CitationFetchService.fetchScholarPublicationsWithInfo()`
- `GoogleScholarService.fetchScholarInfo()`
- `ScholarDataService.fetchScholarInfo()`

---

### 2. 引用页面
```
https://scholar.google.com/scholar?hl=en&cites={clusterId}&scisbd={1|0}&start={startIndex}
```

**参数说明**:
- `cites`: 论文的 cluster ID
- `scisbd`: 排序方式 (`1`=按日期, `0`=按相关性)
- `start`: 起始索引（分页）

**访问此URL的函数**:
- `CitationFetchService.fetchCitingPapersForClusterId()`

---

### 3. 作者搜索页面
```
https://scholar.google.com/citations?hl=en&view_op=search_authors&mauthors={authorName}
```

**访问此URL的函数**:
- `CitationFetchService.fetchAuthorDetails()` (保留接口，未使用)

---

### 4. 论文详情页面
```
https://scholar.google.com/scholar?hl=en&cluster={paperId}
```

**访问此URL的函数**:
- `CitationFetchService.fetchPaperDetails()` (保留接口，未使用)

---

## 调用流程图

### Dashboard 刷新流程
```
用户下拉刷新
  ↓
CiteTrackApp.refreshAllScholarsAsync()
  ↓
ScholarDataService.fetchAndUpdateScholarsWithCoordinator()
  ↓
CitationFetchCoordinator.fetchScholarComprehensive()
  ↓
任务队列:
  1. scholarBasicInfo (high)
  2. scholarPublications(total, 0) (high)
  3. scholarPublications(pubdate, 0) (high)
  4. scholarPublications(title, 0) (high)
  5-10. 后续页面预取 (medium)
  ↓
CitationFetchService.fetchScholarPublicationsWithInfo()
  ↓
访问: https://scholar.google.com/citations?user=...
```

### Who Cite Me 页面流程
```
用户打开 Who Cite Me
  ↓
WhoCiteMeView.onAppear
  ↓
CitationManager.fetchScholarPublications()
  ↓
检查缓存 → 如果不存在
  ↓
CitationFetchCoordinator.fetchScholarPublicationsWithPrefetch()
  ↓
CitationFetchService.fetchScholarPublicationsWithInfo()
  ↓
访问: https://scholar.google.com/citations?user=...&sortby=total
```

### 查看论文引用流程
```
用户点击论文
  ↓
WhoCiteMeView.showCitingPapers()
  ↓
CitationFetchService.fetchCitingPapersForClusterId()
  ↓
访问: https://scholar.google.com/scholar?cites={clusterId}&scisbd=1
```

---

## 注意事项

1. **所有访问都通过协调器**: 推荐使用 `CitationFetchCoordinator` 的方法，而不是直接调用 `CitationFetchService`
2. **缓存优先**: 所有函数都会先检查缓存，只有缓存不存在或过期时才访问 Google Scholar
3. **速率限制**: 协调器自动控制请求间隔（2-3秒），避免触发反爬虫
4. **批量预取**: `fetchScholarComprehensive()` 会一次性获取多种排序方式和多个页面，最大化数据获取

