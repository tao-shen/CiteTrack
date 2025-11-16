# Who Cite Me 功能快速测试指南

## 问题已修复 ✅

您在iOS应用中遇到的"Who Cite Me"功能数据显示为0的问题已经修复。

## 快速测试步骤

### 1. 重新编译应用（如需要）
在Xcode中重新编译运行应用，或使用命令行：
```bash
cd /Users/tao.shen/google_scholar_plugin/iOS
xcodebuild -project CiteTrack_iOS.xcodeproj -scheme CiteTrack \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 2. 打开应用并测试
1. 启动CiteTrack应用
2. 进入"Who Cite Me"标签页（最右侧的引号图标）
3. 从顶部选择器中选择一个学者
4. 点击右上角的刷新按钮

### 3. 观察加载过程
- **首次加载**：会显示加载指示器
- **加载时间**：约30秒-1分钟（取决于论文数量）
- **控制台日志**：可以在Xcode控制台查看详细的日志输出

### 4. 验证结果
加载完成后，应该看到：

#### 统计卡片区域
- **total_citing_papers**: 显示总引用论文数（例如：42）
- **unique_authors**: 显示唯一作者数（例如：28）
- **average_per_year**: 显示年均引用数（例如：5.2）

#### 引用论文列表
- 显示具体的引用论文
- 每篇论文包含：标题、作者、年份、引用数、期刊/会议

## 常见问题

### Q: 为什么加载时间这么长？
A: 因为需要：
1. 先获取学者的论文列表
2. 为每篇论文（最多10篇）单独获取引用列表
3. 每个请求之间有2.5秒延迟以避免被Google Scholar限流

### Q: 数据仍然显示为0怎么办？
A: 请检查：
1. 网络连接是否正常
2. 能否访问Google Scholar
3. 学者ID是否正确
4. 查看Xcode控制台是否有错误日志

### Q: 可以看到部分数据但不完整
A: 这是正常的，可能原因：
1. 某些论文的引用获取失败（会跳过继续处理）
2. 限制了最多处理10篇论文（避免请求过多）
3. 部分论文可能没有cluster ID

### Q: 如何查看详细日志？
A: 在Xcode中运行应用，打开控制台，搜索：
- `[CitationFetch]` - 引用数据获取相关日志
- `[CitationManager]` - 引用数据管理相关日志

## 日志示例

### 成功的日志输出
```
ℹ️ [CitationManager] Fetching citing papers for scholar: ABC123
ℹ️ [CitationFetch] Fetching scholar profile: ABC123
✅ [CitationFetch] Parsed 15 publications
ℹ️ [CitationFetch] Fetching citations for 10 publications...
ℹ️ [CitationFetch] Progress: 1/10 - Found 5 citations
ℹ️ [CitationFetch] Progress: 2/10 - Found 3 citations
...
✅ [CitationFetch] Completed: found 42 total citing papers
✅ [CitationManager] Fetched 42 citing papers
```

### 错误的日志输出
```
❌ [CitationFetch] Network error: The Internet connection appears to be offline
```
或
```
❌ [CitationFetch] Scholar not found: ABC123
```

## 缓存说明
- 成功获取的数据会被缓存
- 下次打开应用会先使用缓存数据（即时显示）
- 可以通过刷新按钮强制重新获取最新数据

## 技术细节
修复详情请参考：`WHO_CITE_ME_FIX.md`

## 需要帮助？
如果仍然遇到问题，请提供：
1. Xcode控制台的完整日志
2. 使用的学者ID
3. 网络环境说明

