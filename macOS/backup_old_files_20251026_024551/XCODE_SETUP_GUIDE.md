# CiteTrack macOS Xcode 项目设置指南

## ✅ 已完成的工作

1. ✅ iOS 项目已重命名为 `CiteTrack_iOS.xcodeproj`
2. ✅ macOS 项目已创建为 `CiteTrack_macOS.xcodeproj`
3. ✅ 项目配置包含：
   - Bundle ID: `com.citetrack.app`
   - 版本: 1.1.3
   - 最低系统: macOS 10.15
   - Sparkle 自动更新框架支持
   - Entitlements 配置

## 📝 接下来需要在 Xcode 中完成的步骤

### 1. 打开项目

```bash
cd /Users/tao.shen/google_scholar_plugin/macOS
open CiteTrack_macOS.xcodeproj
```

### 2. 添加所有源文件

项目目前只包含两个基础文件（`main.swift` 和 `Localization.swift`）。您需要添加 `Sources/` 目录下的其他文件：

**方法：**
1. 在 Xcode 左侧项目导航器中，右键点击 "Sources" 组
2. 选择 "Add Files to 'CiteTrack'..."
3. 选择 `Sources/` 目录下的所有其他 Swift 文件：
   - ChartDataService.swift
   - ChartsViewController.swift
   - ChartsWindowController.swift
   - ChartTheme.swift
   - ChartView.swift
   - CitationHistory.swift
   - CitationHistoryEntity.swift
   - CitationHistoryManager.swift
   - CoreDataManager.swift
   - DashboardComponents.swift
   - DataRepairViewController.swift
   - EnhancedChartTypes.swift
   - GoogleScholarService+History.swift
   - iCloudSyncManager.swift
   - ModernCardView.swift
   - ModernChartsViewController.swift
   - ModernChartsWindowController.swift
   - ModernToolbar.swift
   - NotificationManager.swift
   - SettingsWindow.swift
   - SettingsWindow_v1.1.3.swift
   - StatisticsView.swift
   - main_localized.swift
   - main_v1.1.3.swift

4. 添加 CoreData 模型：
   - 选择 `Sources/CitationTrackingModel.xcdatamodeld` 文件夹

5. 确保在添加时勾选：
   - ☑️ "Copy items if needed" (如果需要)
   - ☑️ 选中 "CiteTrack" target

### 3. 添加资源文件

1. 在项目导航器中创建一个 "Resources" 组
2. 添加图标文件：
   - 右键点击 "Resources" → "Add Files..."
   - 选择 `assets/app_icon.icns`

### 4. 配置 Sparkle 框架

框架引用已添加，但需要验证：

1. 在项目设置中，选择 "CiteTrack" target
2. 进入 "General" 标签页
3. 在 "Frameworks, Libraries, and Embedded Content" 部分
4. 确认 `Sparkle.framework` 已正确链接，并设置为 "Embed & Sign"

### 5. 配置 Build Settings

检查以下设置（应该已自动配置）：

- **Framework Search Paths**: `$(PROJECT_DIR)/Frameworks`
- **Runpath Search Paths**: `@executable_path/../Frameworks`
- **Code Signing**: 根据您的开发者账户配置

### 6. 配置 Entitlements

entitlements 文件已存在（`CiteTrack.entitlements`），包含：
- App Sandbox
- 网络访问
- iCloud 支持（CloudKit + CloudDocuments）

如需修改，在 Xcode 中编辑此文件。

### 7. 添加 Shared 文件（可选）

如果需要使用 `../Shared/` 目录中的文件：

1. 右键点击项目根目录
2. "Add Files to 'CiteTrack'..."
3. 导航到 `../Shared/` 目录
4. 选择需要的文件（如 `Constants.swift`）
5. **重要**: 不要勾选 "Copy items if needed"，保持文件在原位置

### 8. 设置应用图标

1. 在 Xcode 中，选择 target "CiteTrack"
2. 进入 "Build Settings"
3. 搜索 "ICNS"
4. 确认 `ASSETCATALOG_COMPILER_APPICON_NAME` 设置正确

或者：
1. 创建 Asset Catalog（如果需要）
2. 添加 App Icon set

### 9. 测试构建

1. 选择 "CiteTrack" scheme
2. 选择 "My Mac" 作为目标设备
3. 点击 Run (⌘R) 或 Build (⌘B)

## 🔧 常见问题

### 问题 1: 找不到 Sparkle.framework

**解决方案:**
- 确保 `Frameworks/Sparkle.framework` 存在
- 在 Build Settings 中检查 Framework Search Paths

### 问题 2: 编译错误 - 找不到某些文件

**解决方案:**
- 确保所有需要的源文件都已添加到项目
- 检查文件的 Target Membership（在 File Inspector 中）

### 问题 3: CoreData 模型问题

**解决方案:**
- 确保 `.xcdatamodeld` 文件夹被正确添加（整个文件夹，不是单个文件）
- 检查模型文件的版本

## 📦 项目结构

```
macOS/
├── CiteTrack_macOS.xcodeproj/     # Xcode 项目文件
├── Sources/                        # 所有源代码
│   ├── main.swift                 # ✅ 已添加
│   ├── Localization.swift         # ✅ 已添加
│   ├── [其他 Swift 文件]          # ⚠️ 需要手动添加
│   └── CitationTrackingModel.xcdatamodeld/  # ⚠️ 需要添加
├── Frameworks/
│   └── Sparkle.framework          # ✅ 已引用
├── assets/
│   └── app_icon.icns              # ⚠️ 需要添加
└── CiteTrack.entitlements         # ✅ 已配置

```

## 🚀 完成后

完成所有文件添加后，您就可以：

1. 在 Xcode 中直接编译和运行
2. 创建 Archive 用于分发
3. 使用 Xcode 的自动签名功能
4. 导出 .app 或创建 .dmg 安装包

## 💡 提示

- 可以通过拖拽方式批量添加文件到 Xcode
- 使用 Xcode 的 "Find in Project" (⌘⇧F) 快速定位问题
- 建议先完成所有文件添加，再尝试编译

---

**注意**: 这是一个最小化但完全可用的 Xcode 项目。您可以根据需要逐步添加功能和文件。

