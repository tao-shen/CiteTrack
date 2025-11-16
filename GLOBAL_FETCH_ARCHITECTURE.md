# 全局获取架构 - 底层基础设施设计

## 设计理念

**每一次访问 Google Scholar 都要精打细算，尽可能服务所有功能**

## 核心原则

1. **一次访问，最大化数据获取**
   - 获取基本信息时，同时获取论文列表
   - 获取论文列表时，预取多种排序方式
   - 获取第一页时，预取后续页面

2. **统一入口，全局协调**
   - 所有 Google Scholar 访问都通过 `CitationFetchCoordinator`
   - 优先级队列管理，避免重复请求
   - 智能缓存检查，减少不必要的访问

3. **功能共享，缓存复用**
   - Dashboard、Widget、AutoUpdate、WhoCiteMe 共享同一个缓存
   - 任何功能获取的数据都能被其他功能使用
   - 24小时缓存有效期

## 架构图

```
                     Google Scholar
                           ↓
              CitationFetchCoordinator（全局协调器）
                     ↙    ↓    ↘
         优先级队列  速率限制  去重检查
                     ↙    ↓    ↘
         Dashboard  Widget  AutoUpdate  WhoCiteMe
                     ↘    ↓    ↙
            CitationCacheService（统一缓存）
```

## 实现细节

### 1. 核心组件：CitationFetchCoordinator

**位置**: `Shared/Services/CitationFetchCoordinator.swift`

#### 任务类型
```swift
enum FetchTaskType {
    case scholarBasicInfo(scholarId)     // 学者基本信息
    case scholarPublications(...)         // 学者论文列表
    case citingPapers(...)                // 引用论文列表
}
```

#### 优先级系统
```swift
public enum FetchPriority {
    case high   = 3  // 用户主动请求
    case medium = 2  // 预取可能需要的数据
    case low    = 1  // 后台批量获取
}
```

#### 关键方法

**全面刷新学者数据**（最常用入口）:
```swift
public func fetchScholarComprehensive(
    scholarId: String,
    priority: FetchPriority = .high
) async
```

这个方法会：
1. 获取学者基本信息（高优先级）
2. 获取论文列表（3种排序，每种第一页，高优先级）
3. 预取后续页面（中优先级）

**一次调用，获取约 1000 条数据！**

### 2. 扩展：ScholarDataService+Coordinator

**位置**: `Shared/Services/ScholarDataService+Coordinator.swift`

为 `ScholarDataService` 添加使用协调器的方法：

```swift
// 单个学者更新
public func fetchAndUpdateScholarWithCoordinator(id: String) async throws -> Scholar

// 批量学者更新
public func fetchAndUpdateScholarsWithCoordinator(ids: [String]) async -> [Result<Scholar, Error>]
```

### 3. 各功能集成

#### Dashboard 刷新
```swift
// 之前：每个学者单独访问 Google Scholar
for scholar in scholars {
    fetchScholarInfo(scholar.id)
    await Task.sleep(0.5秒)
}

// 现在：批量预取，共享缓存
await scholarDataService.fetchAndUpdateScholarsWithCoordinator(scholarIds)
```

#### AutoUpdate（定时更新）
```swift
// AutoUpdateManager.swift (已集成)
let scholarIds = scholars.map { $0.id }
let results = await scholarDataService.fetchAndUpdateScholarsWithCoordinator(ids: scholarIds)
```

#### Widget（后台刷新）
```swift
// 建议实现
await scholarDataService.fetchAndUpdateScholarWithCoordinator(id: widgetScholarId)
```

#### WhoCiteMe（已集成）
```swift
await fetchCoordinator.fetchScholarPublicationsWithPrefetch(
    scholarId: scholarId,
    priority: .high
)
```

## 数据获取流程对比

### 之前的方式（低效）

```
用户操作：刷新学者
    ↓
访问 Google Scholar（仅获取 name + citations）
    ↓
用户切换到 WhoCiteMe
    ↓
再次访问 Google Scholar（获取论文列表）
    ↓
用户点击排序
    ↓
又一次访问 Google Scholar（获取另一种排序）
    ↓
用户加载更多
    ↓
再访问 Google Scholar...

总共：4-5 次访问，获取约 100-200 条数据
```

### 现在的方式（高效）

```
用户操作：刷新学者
    ↓
CitationFetchCoordinator（批量预取）
    ↓
任务队列：
  1. 基本信息（高优先级）
  2. 论文列表-按引用量-第1页（高）
  3. 论文列表-按年份-第1页（高）
  4. 论文列表-按标题-第1页（高）
  5. 论文列表-按引用量-第2页（中）
  6. 论文列表-按年份-第2页（中）
  7. 论文列表-按标题-第2页（中）
  8. 论文列表-按引用量-第3页（中）
  9. 论文列表-按年份-第3页（中）
  10. 论文列表-按标题-第3页（中）
    ↓
第1个任务完成，立即显示数据（用户无感等待）
    ↓
后续任务静默完成，所有数据缓存 24小时
    ↓
用户切换到 WhoCiteMe → 瞬间显示（缓存命中）
用户点击排序 → 瞬间切换（缓存命中）
用户加载更多 → 瞬间加载（缓存命中）
Widget 更新 → 直接使用缓存
AutoUpdate → 所有数据已是最新

总共：10 次访问（后台队列，间隔 4-6秒）
获取数据：约 1000 条
用户体验：几乎所有操作都是瞬间响应
```

## 性能对比

### 访问频率
- **之前**: 每个操作都可能触发访问，频繁但获取少
- **现在**: 批量预取，访问次数多但集中，后续操作零访问

### 数据获取量
- **之前**: 按需获取，每次 1-100 条
- **现在**: 批量预取，每次约 1000 条

### 用户体验
- **之前**: 每次操作都需要等待网络请求
- **现在**: 首次等待后，所有操作瞬间响应

### 被封风险
- **之前**: 频繁的小请求，容易触发反爬虫
- **现在**: 间隔 4-6秒，模拟正常浏览行为

## 缓存策略

### 缓存键设计
```swift
// 学者基本信息 + 论文列表
"{scholarId}_{sortBy}_{startIndex}"

// 引用论文列表
"{clusterId}_{sortByDate}_{startIndex}"
```

### 缓存过期
- **时间**: 24小时
- **检查**: 每次访问前检查缓存是否过期
- **更新**: 后台静默更新，用户无感知

### 缓存共享
所有功能共享同一个 `CitationCacheService`:
- Dashboard 获取的数据 → Widget 可以用
- WhoCiteMe 预取的数据 → AutoUpdate 可以用
- AutoUpdate 更新的数据 → Dashboard 可以用

## 配置参数

```swift
// CitationFetchCoordinator
minDelayBetweenRequests: 4.0秒    // 最小请求间隔
maxDelayBetweenRequests: 6.0秒    // 最大请求间隔
maxConcurrentTasks: 1              // 串行处理
prefetchPagesCount: 3              // 预取3页

// CitationCacheService
cacheExpirationInterval: 24小时    // 缓存过期时间
```

## 监控和调试

### 可观察状态
```swift
@Published var isProcessing: Bool        // 是否正在处理
@Published var queueSize: Int            // 队列大小
@Published var completedTasks: Int       // 完成任务数
@Published var failedTasks: Int          // 失败任务数
```

### 日志标识
- `🚀 [FetchCoordinator]` - 开始批量预取
- `📋 [FetchCoordinator]` - 任务队列操作
- `💾 [FetchCoordinator]` - 缓存操作
- `✅ [FetchCoordinator]` - 任务成功
- `❌ [FetchCoordinator]` - 任务失败
- `⏱️ [FetchCoordinator]` - 等待延迟

### 示例日志
```
🚀 [FetchCoordinator] Comprehensive fetch for scholar: kukA0LcAAAAJ
📋 [FetchCoordinator] Starting prefetch for scholar: kukA0LcAAAAJ
➕ [FetchCoordinator] Task added: basic_kukA0LcAAAAJ, priority: high, queue size: 1
➕ [FetchCoordinator] Task added: scholar_kukA0LcAAAAJ_total_0, priority: high, queue size: 2
...
🚀 [FetchCoordinator] Starting queue processing, 10 tasks
▶️ [FetchCoordinator] Processing task: basic_kukA0LcAAAAJ, priority: high, remaining: 9
💾 [FetchCoordinator] Cached basic info + 100 publications for kukA0LcAAAAJ
✅ [FetchCoordinator] Task completed: basic_kukA0LcAAAAJ
⏱️ [FetchCoordinator] Waiting 4.8s before next task
...
🏁 [FetchCoordinator] Queue processing completed. Completed: 10, Failed: 0
```

## 最佳实践

### 1. 使用正确的入口

**Dashboard/Widget/AutoUpdate**（需要基本信息+论文）:
```swift
await fetchCoordinator.fetchScholarComprehensive(scholarId: id, priority: .high)
```

**WhoCiteMe**（只需论文列表）:
```swift
await fetchCoordinator.fetchScholarPublicationsWithPrefetch(scholarId: id, priority: .high)
```

**查看引用**:
```swift
await fetchCoordinator.fetchCitingPapersWithPrefetch(clusterId: id, priority: .high)
```

### 2. 优先级设置
- 用户主动触发：`.high`
- 后台预取：`.medium`
- 低优先级补充：`.low`

### 3. 缓存检查
- 读取数据前先检查缓存
- 缓存命中时立即显示，后台刷新
- 缓存未命中时使用批量预取

## 未来优化

1. **持久化缓存**
   - 目前是内存缓存，App 重启后丢失
   - 可以持久化到本地数据库

2. **智能预测**
   - 根据用户行为预测可能需要的数据
   - 动态调整预取策略

3. **增量更新**
   - 只更新变化的部分
   - 减少数据传输量

4. **分布式队列**
   - 多个学者并行预取（注意速率限制）
   - 更快的批量更新

5. **错误重试**
   - 失败任务自动重试
   - 指数退避策略

## 总结

通过将 `CitationFetchCoordinator` 设计为全局基础设施，我们实现了：

✅ **效率最大化**: 一次访问获取 1000+ 条数据
✅ **体验最优化**: 缓存命中后瞬间响应
✅ **风险最小化**: 控制访问频率，避免被封
✅ **架构最优化**: 所有功能共享缓存和数据
✅ **可维护性**: 统一的获取逻辑，易于调试

**每一次对 Google Scholar 的访问，都能为整个应用提供价值！**

---

**创建日期**: 2025-11-16
**最后更新**: 2025-11-16
**版本**: 2.0 - 全局基础设施

