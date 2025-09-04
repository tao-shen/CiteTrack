# 新数据架构使用指南

## 概览

重构后的数据架构提供了统一、一致、高效的数据管理解决方案。本文档详细说明如何使用新的数据架构。

## 核心组件

### 1. DataServiceCoordinator (数据服务协调器)
统一的数据服务入口点，负责协调所有数据操作。

```swift
// 获取全局实例
let coordinator = DataServiceCoordinator.shared

// 初始化数据服务（通常在应用启动时调用）
try await coordinator.initialize()

// 检查是否准备就绪
if coordinator.isReady {
    // 可以开始使用数据服务
}
```

### 2. NewDataManager (新数据管理器)
主要的数据管理接口，提供高级的数据操作方法。

```swift
// 获取全局实例
let dataManager = NewDataManager.shared

// 添加学者
let scholar = Scholar(id: "scholar123", name: "John Doe")
await dataManager.addScholar(scholar)

// 获取所有学者
let scholars = dataManager.scholars // 响应式数据

// 刷新学者数据
await dataManager.refreshAllScholars()
```

### 3. WidgetDataService (Widget数据服务)
专门为Widget提供的数据服务。

```swift
let widgetService = WidgetDataService.shared

// 获取Widget数据
let widgetData = try await widgetService.getWidgetData()

// 切换学者
try await widgetService.switchToNextScholar()

// 记录刷新动作
await widgetService.recordRefreshAction()
```

## 使用示例

### 在视图中使用数据

```swift
struct ContentView: View {
    @EnvironmentObject var dataManager: NewDataManager
    @EnvironmentObject var dataCoordinator: DataServiceCoordinator
    
    var body: some View {
        VStack {
            if dataManager.isReady {
                // 显示学者列表
                List(dataManager.scholars) { scholar in
                    ScholarRow(scholar: scholar)
                }
            } else {
                // 显示加载状态
                ProgressView("正在加载...")
            }
        }
        .task {
            // 视图出现时刷新数据
            await dataManager.refreshAllScholars()
        }
    }
}
```

### 在Widget中使用数据

```swift
struct WidgetProvider: TimelineProvider {
    private let widgetService = WidgetDataService.shared
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        Task {
            do {
                let widgetData = try await widgetService.getWidgetData()
                
                let entry = WidgetEntry(
                    date: Date(),
                    scholars: widgetData.scholars,
                    selectedScholar: widgetData.selectedScholarId
                )
                
                let timeline = Timeline(entries: [entry], policy: .atEnd)
                completion(timeline)
            } catch {
                // 处理错误
                let fallbackEntry = WidgetEntry.placeholder()
                let timeline = Timeline(entries: [fallbackEntry], policy: .atEnd)
                completion(timeline)
            }
        }
    }
}
```

### 网络数据获取

```swift
let scholarService = ScholarDataService.shared

// 获取并更新学者数据
do {
    let updatedScholar = try await scholarService.fetchAndUpdateScholar(id: "scholar123")
    print("更新成功: \(updatedScholar.name)")
} catch {
    print("更新失败: \(error)")
}

// 批量更新多个学者
let results = await scholarService.fetchAndUpdateScholars(ids: ["scholar1", "scholar2"])
for result in results {
    switch result {
    case .success(let scholar):
        print("成功: \(scholar.name)")
    case .failure(let error):
        print("失败: \(error)")
    }
}
```

## 数据同步

### 自动同步

系统会自动处理数据同步，确保主应用和Widget之间的数据一致性。

```swift
// 启动同步监控（通常在应用启动时自动启动）
DataSyncMonitor.shared.startMonitoring()

// 手动触发同步
await DataSyncMonitor.shared.forceSyncNow()

// 获取同步状态
let syncStatus = DataSyncMonitor.shared.getSyncStatusSummary()
print(syncStatus.description)
```

### 手动同步

```swift
// 通过数据管理器触发同步
await dataManager.triggerSync()

// 通过协调器触发同步
await dataCoordinator.triggerSync()
```

## 错误处理

### 统一错误处理

```swift
do {
    try await dataManager.addScholar(scholar)
} catch let error as DataRepositoryError {
    switch error {
    case .scholarNotFound(let id):
        print("学者未找到: \(id)")
    case .invalidData(let message):
        print("无效数据: \(message)")
    case .syncFailure(let message):
        print("同步失败: \(message)")
    case .storageError(let underlyingError):
        print("存储错误: \(underlyingError)")
    case .validationError(let message):
        print("验证错误: \(message)")
    }
} catch {
    print("未知错误: \(error)")
}
```

### 错误恢复

```swift
// 验证数据完整性
if let validationResult = await dataManager.validateData() {
    if !validationResult.isValid {
        print("发现数据问题: \(validationResult.issues)")
        
        // 尝试自动修复
        await dataManager.repairData()
    }
}
```

## 数据观察

### 响应式数据绑定

```swift
struct ScholarListView: View {
    @EnvironmentObject var dataManager: NewDataManager
    
    var body: some View {
        List(dataManager.scholars) { scholar in
            Text(scholar.name)
        }
        // scholars是@Published属性，会自动更新UI
    }
}
```

### 手动观察数据变化

```swift
class ScholarViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 观察学者数据变化
        dataCoordinator.scholarsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scholars in
                self?.updateUI(with: scholars)
            }
            .store(in: &cancellables)
        
        // 观察同步状态变化
        dataCoordinator.syncStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateSyncIndicator(status: status)
            }
            .store(in: &cancellables)
    }
}
```

## 测试和调试

### 运行集成测试

```swift
let tests = DataIntegrationTests()

// 运行完整测试套件
let results = await tests.runCompleteTestSuite()
print(results.description)

// 快速健康检查
let healthCheck = await tests.quickHealthCheck()
print(healthCheck.description)
```

### 调试信息

```swift
// 获取Widget调试信息
let debugInfo = await WidgetDataService.shared.getDebugInfo()
print(debugInfo.description)

// 获取同步报告
let syncReport = await DataSyncMonitor.shared.getDetailedSyncReport()
print(syncReport.description)

// 获取请求统计
let requestStats = ScholarDataService.shared.getRequestStatistics()
print(requestStats.description)
```

## 最佳实践

### 1. 应用启动时初始化

```swift
@main
struct CiteTrackApp: App {
    @StateObject private var dataManager = NewDataManager.shared
    @StateObject private var dataCoordinator = DataServiceCoordinator.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(dataCoordinator)
                .task {
                    // 应用启动时初始化数据服务
                    do {
                        try await dataCoordinator.initialize()
                    } catch {
                        print("数据服务初始化失败: \(error)")
                    }
                }
        }
    }
}
```

### 2. 错误状态处理

```swift
struct ContentView: View {
    @EnvironmentObject var dataManager: NewDataManager
    
    var body: some View {
        Group {
            if dataManager.isLoading {
                ProgressView("加载中...")
            } else if dataManager.hasError {
                ErrorView(message: dataManager.errorMessage ?? "未知错误")
            } else if dataManager.isReady {
                MainContentView()
            } else {
                Text("初始化中...")
            }
        }
    }
}
```

### 3. 性能优化

```swift
// 使用批量操作而不是单个操作
await dataManager.addScholars(scholars) // 好
// 避免：
// for scholar in scholars {
//     await dataManager.addScholar(scholar) // 慢
// }

// 使用搜索而不是全量加载
let results = dataManager.searchScholars(by: "query") // 好
// 避免手动过滤全部数据
```

## 迁移指南

### 从旧架构迁移

1. **替换DataManager调用**：
   ```swift
   // 旧方式
   DataManager.shared.addScholar(scholar)
   
   // 新方式
   await NewDataManager.shared.addScholar(scholar)
   ```

2. **更新UI绑定**：
   ```swift
   // 旧方式
   @ObservedObject var dataManager = DataManager.shared
   
   // 新方式
   @EnvironmentObject var dataManager: NewDataManager
   ```

3. **更新Widget代码**：
   ```swift
   // 旧方式
   let scholars = loadScholars() // 直接读取存储
   
   // 新方式
   let widgetData = try await WidgetDataService.shared.getWidgetData()
   let scholars = widgetData.scholars
   ```

数据迁移会在应用首次启动时自动进行，无需手动操作。
