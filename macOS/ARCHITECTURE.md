# CiteTrack macOS 软件架构图

## 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        CiteTrack macOS App                      │
├─────────────────────────────────────────────────────────────────┤
│  AppDelegate (main.swift)                                      │
│  ├─ Status Bar Management                                      │
│  ├─ Menu Management                                            │
│  ├─ Background Data Collection                                   │
│  └─ Sparkle Auto-Update                                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    UI Layer (Cocoa)                            │
├─────────────────────────────────────────────────────────────────┤
│  SettingsWindowController                                      │
│  ├─ General Settings Tab                                       │
│  ├─ Scholar Management Tab                                     │
│  └─ Data Management Tab                                        │
│                                                                 │
│  ChartsWindowController                                         │
│  ├─ ModernChartsViewController                                │
│  ├─ ModernToolbar                                              │
│  ├─ DashboardView                                              │
│  └─ InsightPanel                                              │
│                                                                 │
│  DataRepairViewController                                      │
│  └─ Data Validation & Repair                                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Business Logic Layer                           │
├─────────────────────────────────────────────────────────────────┤
│  DataManager (统一数据管理)                                     │
│  ├─ Scholar Management                                         │
│  ├─ Data Import/Export                                         │
│  └─ iOS Compatibility                                          │
│                                                                 │
│  PreferencesManager                                            │
│  ├─ App Settings                                               │
│  ├─ Scholar List                                               │
│  └─ User Preferences                                           │
│                                                                 │
│  GoogleScholarService                                          │
│  ├─ Scholar ID Validation                                      │
│  ├─ Web Scraping                                               │
│  └─ Data Parsing                                               │
│                                                                 │
│  CitationHistoryManager                                         │
│  ├─ History Storage                                             │
│  ├─ Statistics Calculation                                     │
│  └─ Data Analysis                                              │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Data Layer                                   │
├─────────────────────────────────────────────────────────────────┤
│  Core Data Stack                                               │
│  ├─ CoreDataManager                                            │
│  ├─ CitationHistoryEntity                                      │
│  └─ Data Migration                                             │
│                                                                 │
│  UserDefaults (Legacy)                                         │
│  ├─ Scholar List Storage                                       │
│  └─ App Settings                                               │
│                                                                 │
│  iCloud Sync                                                   │
│  ├─ iCloudSyncManager                                          │
│  └─ CloudKit Integration                                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                  External Services                             │
├─────────────────────────────────────────────────────────────────┤
│  Google Scholar                                                │
│  ├─ Scholar Profile Pages                                       │
│  └─ Citation Data                                              │
│                                                                 │
│  iCloud                                                         │
│  ├─ Data Synchronization                                       │
│  └─ Cross-Device Sync                                          │
│                                                                 │
│  Sparkle Framework                                             │
│  └─ Auto-Update System                                         │
└─────────────────────────────────────────────────────────────────┘
```

## 数据流图

```
iOS Data Export
       │
       ▼
┌─────────────────┐
│ JSON File       │
│ (citation_data) │
└─────────────────┘
       │
       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ DataManager     │───▶│ Scholar Import  │───▶│ UserDefaults    │
│ .importFromiOS  │    │ .addScholar()   │    │ Storage         │
│ Data()          │    │ .updateScholar()│    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
       │                        │                        │
       ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ History Import  │───▶│ Core Data       │───▶│ CitationHistory │
│ .importHistory  │    │ Storage         │    │ Entity          │
│ Data()          │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
       │
       ▼
┌─────────────────┐
│ UI Update       │
│ .loadData()     │
│ .reloadData()   │
└─────────────────┘
```

## 关键组件说明

### 1. AppDelegate (main.swift)
- **职责**: 应用程序生命周期管理
- **功能**: 
  - 状态栏管理
  - 菜单构建
  - 后台数据收集
  - 自动更新

### 2. DataManager
- **职责**: 统一数据管理
- **功能**:
  - 学者数据管理
  - iOS 数据导入/导出
  - 数据格式转换
  - 跨平台兼容性

### 3. PreferencesManager
- **职责**: 应用设置和学者列表管理
- **功能**:
  - 应用偏好设置
  - 学者列表存储
  - 用户配置管理

### 4. GoogleScholarService
- **职责**: Google Scholar 数据获取
- **功能**:
  - Scholar ID 验证
  - 网页数据抓取
  - 引用数据解析

### 5. CitationHistoryManager
- **职责**: 历史数据管理
- **功能**:
  - 历史记录存储
  - 统计数据计算
  - 数据分析

### 6. Core Data Stack
- **职责**: 数据持久化
- **功能**:
  - 数据模型管理
  - 数据迁移
  - 关系管理

## 数据导入问题分析

### 问题根源
1. **方法可见性**: `addScholar` 和 `updateScholar` 方法没有声明为 `public`
2. **数据存储**: 导入的数据只保存到 `DataManager` 的 `scholars` 数组，但没有同步到 `PreferencesManager`
3. **UI 更新**: 导入后没有正确触发 UI 刷新

### 解决方案
1. ✅ 修复方法可见性（已完成）
2. 🔄 需要同步数据到 PreferencesManager
3. 🔄 需要触发 UI 更新通知

## 修复建议

### 1. 数据同步问题
```swift
// 在 DataManager.addScholar() 中添加
public func addScholar(_ scholar: Scholar) {
    if !scholars.contains(where: { $0.id == scholar.id }) {
        scholars.append(scholar)
        saveScholars()
        
        // 同步到 PreferencesManager
        PreferencesManager.shared.addScholar(scholar)
        
        // 发送数据更新通知
        NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
        
        print("✅ [DataManager] 添加了学者: \(scholar.name)")
    }
}
```

### 2. UI 更新问题
```swift
// 在 SettingsWindowController.importData() 中
DispatchQueue.main.async(qos: .userInitiated) {
    self.showAlert(
        title: "导入成功",
        message: "成功导入 \(result.importedScholars) 位学者和 \(result.importedHistory) 条历史记录"
    )
    self.loadData() // 重新加载数据
    self.tableView.reloadData() // 刷新表格
}
```

这个架构图显示了完整的软件结构，以及数据导入问题的根本原因和解决方案。
