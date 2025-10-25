# 手动将 Xcode 项目更新到 v2.0.0 的步骤

## 步骤 1: 打开 Xcode 项目
```bash
open CiteTrack_macOS.xcodeproj
```

## 步骤 2: 移除 v1.1.3 文件

在 Xcode 左侧的 Project Navigator 中：
1. 右键点击 `main_v1.1.3.swift` → Delete → Move to Trash
2. 右键点击 `SettingsWindow_v1.1.3.swift` → Delete → Move to Trash

## 步骤 3: 添加 v2.0.0 源文件

右键点击 `Sources` 组 → Add Files to "CiteTrack_macOS"...

添加以下文件（都在 Sources 目录中）：
- [ ] main.swift
- [ ] SettingsWindow.swift  
- [ ] CoreDataManager.swift
- [ ] CitationHistoryEntity.swift
- [ ] CitationHistory.swift
- [ ] CitationHistoryManager.swift
- [ ] GoogleScholarService+History.swift
- [ ] ChartDataService.swift
- [ ] ChartView.swift
- [ ] ChartsViewController.swift
- [ ] ChartsWindowController.swift
- [ ] DataRepairViewController.swift
- [ ] iCloudSyncManager.swift
- [ ] NotificationManager.swift
- [ ] DashboardComponents.swift
- [ ] EnhancedChartTypes.swift
- [ ] ModernCardView.swift

确保勾选 "Copy items if needed" 和 "CiteTrack" target

## 步骤 4: 添加 Core Data 模型

右键点击 `Sources` 组 → Add Files to "CiteTrack_macOS"...
添加: `CitationTrackingModel.xcdatamodeld`

## 步骤 5: 添加框架

点击项目 → 选择 "CiteTrack" target → Build Phases → Link Binary With Libraries

点击 "+" 添加：
- [ ] CoreData.framework
- [ ] UserNotifications.framework

## 步骤 6: 更新版本号

点击项目 → 选择 "CiteTrack" target → General
- Version: 2.0.0
- Build: 2.0.0

## 步骤 7: 清理并编译

Product → Clean Build Folder (Shift+Cmd+K)
Product → Build (Cmd+B)

## 验证

编译应该成功，没有错误和警告！

## v2.0.0 新功能
- 📈 专业图表系统（线图、柱状图、面积图）
- 📊 历史数据追踪和 Core Data 持久化
- 🔔 智能通知系统
- 📤 数据导出（CSV/JSON）
- 💾 iCloud 同步支持

