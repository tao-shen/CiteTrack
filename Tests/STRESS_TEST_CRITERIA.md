# CiteTrack 压力测试完成标准 (Stress Test Completion Criteria)

基于 **iterative-development** 技能：明确“完成”定义，失败即迭代修复，直至全部通过。

## 运行方式

```bash
# 仅压力测试
swift Tests/CiteTrackStressTests.swift

# 功能 + 压力 一键运行（推荐）
chmod +x Tests/run_all_tests.sh
./Tests/run_all_tests.sh
```

可选环境变量：`CITETRACK_PROJECT_ROOT=/path/to/repo` 指定项目根目录。

## 完成条件 (Exit Condition)

- [ ] **CiteTrackTests.swift**：56/56 通过（功能与规范）
- [ ] **CiteTrackStressTests.swift**：52/52 通过（压力 + V1 暴力防闪退 + V2 极压全链路防崩）
- [ ] 无新增 lint/编译错误

当上述全部满足时，可视为 **压力 + 极压测试通过**。  
（参考 [Superpowers](https://github.com/obra/superpowers)：**Evidence over claims** — 先验证再宣布成功。）

## 压力测试维度 (S1–S9)

| 维度 | 内容 | 通过标准 |
|------|------|----------|
| **S1 并发与串行化** | main / FetchService / HistoryManager 使用串行队列；若使用 .concurrent 则写操作用 .barrier | 8/8 |
| **S2 速率限制** | 存在 rateLimit/asyncAfter，无 Thread.sleep 阻塞 | 3/3 |
| **S3 批量与内存** | Core Data 使用 fetchBatchSize；批量删除用 NSBatchDeleteRequest；无单次无限制 fetch | 5/5 |
| **S4 Main Thread 安全** | 关键路径无 Thread.sleep(forTimeInterval:)；无 nonisolated(unsafe)；@MainActor 使用正确 | 5/5 |
| **S5 缓存边界** | 缓存有 TTL；持久化解码失败时有清理 | 3/3 |
| **S6 错误处理** | 不解码静默 try?；错误信息可追踪 | 3/3 |
| **S7 取消与任务** | 有 Cancellable/Task/请求队列，避免请求风暴 | 2/2 |
| **S8 数据一致性** | Core Data 背景 context 有 mergePolicy 与自动合并 | 2/2 |
| **S9 压力代码模式** | statusBarItem/menu 为 optional；无 force unwrap；存在并发测试 | 3/3 |
| **V1 暴力/防闪退** | 无 .first!/.last!、errors.first!、optional!；Widget 无 selected!；空数组安全；as! 前有类型检查 | 10/10 |
| **V2 极压/全链路防崩** | ChartView/EnhancedChartTypes 无 trendLine.points.first!/.last!、points.last!；components[0] 前有 count/guard；无 try!；points[0] 前有 guard；无裸 catch 吞错 | 8/8 |

## 错误分类 (Error Classification)

- **代码/逻辑错误**：断言失败、类型错误 → 继续迭代修复。
- **环境/权限错误**：文件不存在、权限不足、依赖缺失 → 停止并输出 Blocker 报告，需人工处理。

## 迭代流程 (TDD Workflow)

1. 运行 `./Tests/run_all_tests.sh`。
2. 若有失败，根据报告分类：代码错误则改代码或测试；环境错误则按 Blocker 报告处理。
3. 重复直到 56+52 全部通过（共 108 条）。
4. 完成后可输出：`<promise>ALL TESTS PASSING STRESS COMPLETE</promise>`（若使用 ralph-loop）。

## V1 暴力/防闪退 (本次新增)

- **GoogleScholarService+History**：`errors.first!` 改为 `errors.first` + else 分支，避免空数组闪退。
- **NotificationManager**：`significantChanges.first!` 改为 `significantChanges.first` + if let。
- **CitationHistory (macOS)**：`history.last!` 改为 `guard let latest = history.last`。
- **ChartDataService**：`sortedHistory.first!/.last!`、`values.min()!/max()!` 改为 guard let + 空数据时返回默认 ChartStatistics；`determineTrend` 内 first!/last! 改为 guard let。
- **Widget**：`selected!.displayName` 改为 `if let selected = selected { ... }`；`scholars[0]` 改为 `scholars.first`，空时 early return。

**V2 极压（本次新增）**
- **ChartView (macOS)**：`trendLine.points.first!/.last!` 改为 `guard let startPoint = ..., let endPoint = ... else { return }`。
- **EnhancedChartTypes**：`points.last!` 改为 `guard let lastPoint = points.last else { return areaPath }`，再用 `lastPoint.x`。

- **GoogleScholarService+History.swift**：`fetchScholarInfoWithRateLimit` 中 `Thread.sleep(forTimeInterval:)` 改为 `requestQueue.asyncAfter(deadline: .now() + delay)`，避免阻塞。
- **CiteTrackStressTests.swift**：S4-1a 改为检测实际调用 `Thread.sleep(forTimeInterval:)` 并纳入 GoogleScholarService+History；S9-1 放宽为接受 `guard let menu = menu` 或 `menu?`。
