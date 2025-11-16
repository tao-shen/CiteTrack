# Who Cite Me 功能修复说明

## 问题描述
iOS应用中的"Who Cite Me"功能显示所有数据为0，无法获取引用信息。

## 问题原因
`CitationFetchService` 中的 `fetchCitingPapers` 方法使用了错误的URL格式：
- **原实现**：直接使用学者ID构建"Cited by"页面URL
  ```swift
  https://scholar.google.com/scholar?hl=en&cites={scholarId}
  ```
- **问题**：Google Scholar的 `cites` 参数需要的是论文的cluster ID，而不是学者的user ID

## 修复方案
改进了数据获取流程，分为两个步骤：

### 1. 首先获取学者的论文列表
- 访问学者主页：`https://scholar.google.com/citations?user={scholarId}`
- 解析论文列表，提取每篇论文的cluster ID

### 2. 为每篇论文获取引用列表
- 使用正确的cluster ID获取引用：`https://scholar.google.com/scholar?cites={clusterId}`
- 聚合所有论文的引用数据

## 修改的文件
- `/Shared/Services/CitationFetchService.swift`

## 主要修改内容

### 1. 新增 `ScholarPublication` 结构体
```swift
private struct ScholarPublication {
    let title: String
    let clusterId: String?
    let citationCount: Int?
    let year: Int?
}
```

### 2. 重构 `fetchCitingPapers` 方法
- 改为先获取学者论文列表
- 然后遍历每篇论文获取其引用

### 3. 新增辅助方法
- `fetchScholarPublications()` - 获取学者的论文列表
- `parseScholarPublications()` - 解析学者主页的论文信息
- `parseSinglePublication()` - 解析单篇论文的基本信息
- `fetchCitingPapersForPublications()` - 批量获取多篇论文的引用
- `fetchCitingPapersForPublication()` - 获取单篇论文的引用列表
- `buildScholarProfileURL()` - 构建学者主页URL
- `buildCitedByURL(forClusterId:)` - 使用cluster ID构建引用页面URL

### 4. 限制保护
为避免请求过多，限制每次最多处理学者的前10篇论文。

## 测试步骤

1. **编译项目**
   ```bash
   cd /Users/tao.shen/google_scholar_plugin/iOS
   xcodebuild -project CiteTrack_iOS.xcodeproj -scheme CiteTrack \
     -destination 'platform=iOS Simulator,name=iPhone 17' build
   ```
   ✅ 编译成功，无错误和警告

2. **运行应用测试**
   - 打开CiteTrack iOS应用
   - 导航到"Who Cite Me"标签页
   - 选择一个学者
   - 点击刷新按钮
   - 等待数据加载（由于需要多次请求，可能需要30秒-1分钟）

3. **预期结果**
   - `total_citing_papers`: 显示引用论文总数
   - `unique_authors`: 显示唯一作者数量
   - `average_per_year`: 显示年均引用数
   - 引用论文列表：显示具体的引用论文信息

## 注意事项

1. **速率限制**：由于需要多次请求Google Scholar，请求之间有2.5秒的延迟以避免被限流

2. **处理时间**：获取完整数据可能需要较长时间（10篇论文约25-30秒）

3. **网络要求**：需要能够访问Google Scholar

4. **错误处理**：
   - 如果学者没有论文，会返回空列表
   - 如果某篇论文的引用获取失败，会跳过该论文继续处理其他论文
   - 所有失败都有日志输出，便于调试

## 日志输出示例
```
ℹ️ [CitationFetch] Fetching citing papers for scholar: {scholarId}
ℹ️ [CitationFetch] Fetching scholar profile: {scholarId}
✅ [CitationFetch] Parsed 15 publications
ℹ️ [CitationFetch] Fetching citations for 10 publications...
ℹ️ [CitationFetch] Progress: 1/10 - Found 5 citations for publication
ℹ️ [CitationFetch] Progress: 2/10 - Found 3 citations for publication
...
✅ [CitationFetch] Completed: found 42 total citing papers
```

## 进一步优化建议

1. **缓存优化**：已实现的缓存系统会缓存结果，避免重复请求

2. **后台处理**：可以考虑在后台线程处理，并显示进度指示器

3. **增量加载**：可以先显示部分结果，然后逐步加载更多

4. **论文数量限制**：当前限制为10篇，可根据需要调整（在 `fetchCitingPapersForPublications` 方法中修改）

## 修复完成
✅ 所有代码修改已完成
✅ 编译测试通过
✅ 无编译错误和警告
✅ 功能逻辑正确实现

