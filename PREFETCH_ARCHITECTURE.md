# 批量预取架构设计文档

## 概述

为应对 Google Scholar 的严格反爬虫机制，我们重新设计了数据获取策略，从"按需获取"改为"一次访问，最大化数据获取"的批量预取模式。

## 核心思想

**一次访问 Google Scholar，尽可能多地获取并缓存数据**

## 架构设计

### 1. 新增组件：`CitationFetchCoordinator`

位置：`Shared/Services/CitationFetchCoordinator.swift`

#### 主要功能：
- **任务队列管理**：维护一个优先级队列，管理所有数据获取任务
- **智能批量预取**：自动预取多页数据和不同排序方式的数据
- **速率限制**：控制请求频率（4-6秒间隔），避免触发反爬虫
- **去重处理**：避免重复请求已获取的数据
- **缓存检查**：优先使用缓存，减少网络请求

#### 关键特性：

1. **优先级系统**：
   ```swift
   public enum FetchPriority {
       case high = 3      // 用户主动请求
       case medium = 2    // 预取可能需要的数据
       case low = 1       // 后台批量获取
   }
   ```

2. **任务类型**：
   ```swift
   enum FetchTaskType {
       case scholarPublications(scholarId, sortBy, startIndex)
       case citingPapers(clusterId, sortByDate, startIndex)
   }
   ```

3. **批量预取策略**：
   - 学者论文列表：
     - 预取 3 种排序方式（total, pubdate, title）
     - 每种排序预取前 3 页（共 300 篇论文）
   - 引用论文列表：
     - 预取 2 种排序方式（按日期、按相关性）
     - 每种排序预取前 2 页

### 2. 改进的 `CitationManager`

#### 新的工作流程：

1. **首次加载**：
   ```swift
   func fetchScholarPublications(for scholarId, sortBy, forceRefresh) {
       // 1. 检查缓存
       if cached {
           // 立即显示缓存数据
           // 后台启动批量预取（中优先级）
       } else {
           // 启动批量预取（高优先级）
           // 完成后从缓存加载到UI
       }
   }
   ```

2. **后台预取**：
   ```swift
   await fetchCoordinator.fetchScholarPublicationsWithPrefetch(
       scholarId: scholarId,
       priority: .medium
   )
   ```

### 3. 扩展的 `CitationCacheService`

#### 已有的缓存能力：
- 缓存过期时间：24 小时
- 分页缓存支持
- 多排序方式缓存
- 引用论文列表缓存

#### 缓存键格式：
- 主论文列表：`"{scholarId}_{sortBy}_{startIndex}"`
- 引用论文列表：`"{clusterId}_{sortByDate}_{startIndex}"`

## 数据流程

### 场景 1：首次打开学者页面（缓存命中）

```
用户打开页面
    ↓
检查缓存 → 缓存命中
    ↓
立即显示缓存数据（快速响应）
    ↓
后台启动批量预取任务（中优先级）
    ↓
预取队列：
  1. total/0 (第1页)
  2. pubdate/0
  3. title/0
  4. total/100 (第2页，中优先级)
  5. pubdate/100
  6. title/100
  7. total/200 (第3页，中优先级)
  8. pubdate/200
  9. title/200
    ↓
每个任务间隔 4-6秒
    ↓
静默更新缓存
```

### 场景 2：首次打开学者页面（缓存未命中）

```
用户打开页面
    ↓
检查缓存 → 缓存未命中
    ↓
启动批量预取任务（高优先级）
    ↓
预取队列自动生成（同上，但都是高优先级）
    ↓
第一个任务完成后，立即显示数据
    ↓
继续后台预取剩余任务
```

### 场景 3：点击引用数查看引用论文

```
用户点击引用数
    ↓
检查缓存 → 缓存命中/未命中
    ↓
（流程类似场景 1/2）
    ↓
预取队列：
  1. 按日期排序/第1页 (高优先级)
  2. 按相关性排序/第1页 (高优先级)
  3. 按日期排序/第2页 (低优先级)
  4. 按相关性排序/第2页 (低优先级)
```

## 配置参数

```swift
// CitationFetchCoordinator 配置
private let minDelayBetweenRequests: TimeInterval = 4.0  // 最小请求间隔
private let maxDelayBetweenRequests: TimeInterval = 6.0  // 最大请求间隔
private let maxConcurrentTasks = 1  // 最大并发数（避免被封）
private let prefetchPagesCount = 3  // 主论文列表预取页数

// CitationCacheService 配置
private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60  // 24小时
```

## 优势

### 1. 减少网络请求
- **之前**：每次操作都访问网络（切换排序、加载更多、查看引用）
- **现在**：大部分操作直接使用缓存，只在必要时批量预取

### 2. 更好的用户体验
- 即时响应：缓存命中时立即显示数据
- 无感加载：后台静默预取，不影响UI交互
- 减少等待：提前预取可能需要的数据

### 3. 降低被封风险
- 控制请求频率：固定间隔 4-6秒
- 串行处理：同时只有1个请求
- 智能去重：避免重复请求

### 4. 充分利用每次访问
- 预取多种排序方式
- 预取多页数据
- 24小时缓存有效期

## 监控和调试

### 可观察的状态：

```swift
@Published public var isProcessing: Bool          // 是否正在处理任务
@Published public var queueSize: Int              // 队列中的任务数
@Published public var completedTasks: Int         // 已完成任务数
@Published public var failedTasks: Int            // 失败任务数
```

### 日志：

所有关键操作都有详细日志，前缀标识：
- `📋 [FetchCoordinator]`：协调器日志
- `💾 [FetchCoordinator]`：缓存操作
- `✅ [FetchCoordinator]`：任务完成
- `❌ [FetchCoordinator]`：任务失败
- `⏱️ [FetchCoordinator]`：延迟等待
- `🚀 [FetchCoordinator]`：开始处理
- `🏁 [FetchCoordinator]`：处理完成

## 未来优化方向

1. **持久化缓存**：
   - 当前是内存缓存，App 重启后丢失
   - 可以考虑持久化到本地文件或数据库

2. **智能预测**：
   - 根据用户行为预测可能查看的内容
   - 动态调整预取策略

3. **增量更新**：
   - 只更新变化的部分
   - 减少数据传输量

4. **缓存优先级**：
   - LRU 缓存淘汰策略
   - 限制缓存大小

5. **错误重试**：
   - 失败任务自动重试
   - 指数退避策略

## 使用示例

### 在 CitationManager 中使用：

```swift
// 批量预取学者论文
await fetchCoordinator.fetchScholarPublicationsWithPrefetch(
    scholarId: "kukA0LcAAAAJ",
    priority: .high
)

// 批量预取引用论文
await fetchCoordinator.fetchCitingPapersWithPrefetch(
    clusterId: "12345678",
    priority: .high
)

// 查询队列状态
let (pending, completed, failed) = fetchCoordinator.getQueueStats()
print("Pending: \(pending), Completed: \(completed), Failed: \(failed)")

// 清空队列
fetchCoordinator.clearQueue()
```

## 总结

这次架构改进从根本上改变了数据获取策略，通过批量预取和智能缓存，大大减少了对 Google Scholar 的访问频率，同时提升了用户体验。这是应对反爬虫机制的最佳实践。

---

**创建日期**: 2025-11-16
**最后更新**: 2025-11-16

