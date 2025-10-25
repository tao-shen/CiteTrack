# 在 Xcode 中创建 macOS 项目并编译调试

## 🎯 推荐方案：在 Xcode 中手动创建项目（5-10 分钟）

自动生成的项目文件容易出现格式问题。使用 Xcode GUI 创建项目更可靠，操作也很简单。

---

## 📝 详细步骤

### 第 1 步：在 Xcode 中创建新项目

1. 打开 Xcode
2. 选择 **File → New → Project...**
3. 选择 **macOS → App**
4. 点击 **Next**

5. 填写项目信息：
   - **Product Name**: `CiteTrack`
   - **Team**: 选择您的开发团队（或留空用于本地调试）
   - **Organization Identifier**: `com.citetrack`
   - **Bundle Identifier**: `com.citetrack.app`
   - **Interface**: `SwiftUI`（或 `AppKit`，根据您的代码选择）
   - **Language**: `Swift`
   - **Storage**: 如果使用 CoreData，勾选 "Use Core Data"
   - 取消勾选 "Include Tests"（可选）

6. 点击 **Next**，选择保存位置为：
   ```
   /Users/tao.shen/google_scholar_plugin/macOS/
   ```
   
7. 取消勾选 "Create Git repository"（因为项目已在 git 中）
8. 点击 **Create**

### 第 2 步：删除默认文件并添加您的源文件

#### 2.1 删除自动生成的文件

在项目导航器中，删除以下默认文件（右键 → Delete → Move to Trash）：
- `CiteTrackApp.swift`（如果自动生成）
- `ContentView.swift`（如果自动生成）
- 其他自动生成的 .swift 文件

#### 2.2 添加您的源文件

1. 在项目导航器中，右键点击 **CiteTrack** 组
2. 选择 **Add Files to "CiteTrack"...**
3. 导航到：`/Users/tao.shen/google_scholar_plugin/macOS/Sources/`
4. 按住 **Command (⌘)** 键，选择所有 .swift 文件：
   - main.swift
   - Localization.swift
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

5. **重要**：确保勾选：
   - ☑️ **Add to targets: CiteTrack**
   - ⚠️ **不要勾选** "Copy items if needed"（文件保持在 Sources/ 目录）

6. 点击 **Add**

#### 2.3 添加 CoreData 模型

1. 右键点击 **CiteTrack** 组 → **Add Files to "CiteTrack"...**
2. 选择 `Sources/CitationTrackingModel.xcdatamodeld` **文件夹**
3. 勾选 "Add to targets: CiteTrack"
4. 点击 **Add**

### 第 3 步：添加 Sparkle 框架

1. 选择项目文件（最顶层的蓝色图标 "CiteTrack"）
2. 选择 **CiteTrack** target
3. 进入 **General** 标签页
4. 在 "Frameworks, Libraries, and Embedded Content" 部分：
   - 点击 **+** 按钮
   - 点击 **Add Other...** → **Add Files...**
   - 导航到 `/Users/tao.shen/google_scholar_plugin/macOS/Frameworks/`
   - 选择 `Sparkle.framework`
   - 确保设置为 **Embed & Sign**

### 第 4 步：配置 Entitlements

1. 在项目导航器中，右键点击 **CiteTrack** 组
2. 选择 **New File...**
3. 选择 **Property List**
4. 命名为 `CiteTrack.entitlements`
5. 或者，直接添加已有的文件：
   - **Add Files to "CiteTrack"...**
   - 选择 `/Users/tao.shen/google_scholar_plugin/macOS/CiteTrack.entitlements`
   - 不勾选 "Copy items if needed"

6. 在项目设置中，选择 **CiteTrack** target → **Signing & Capabilities**
7. 在 **Code Signing Entitlements** 中设置：`CiteTrack.entitlements`

### 第 5 步：配置 Build Settings

1. 选择项目 → CiteTrack target → **Build Settings**
2. 搜索并设置以下项：

   **Framework Search Paths**:
   ```
   $(inherited)
   $(PROJECT_DIR)/Frameworks
   ```

   **Runpath Search Paths**:
   ```
   $(inherited)
   @executable_path/../Frameworks
   ```

   **Marketing Version**: `1.1.3`
   
   **macOS Deployment Target**: `10.15`

### 第 6 步：配置 Info.plist（如果需要）

Xcode 14+ 会自动生成 Info.plist。如果需要自定义，可以在项目设置中：
- 选择 target → **Info** 标签页
- 添加自定义键值对

或者添加自定义键到 **Build Settings → Packaging**：
- `INFOPLIST_KEY_LSUIElement` = `YES`（后台应用）
- `INFOPLIST_KEY_NSPrincipalClass` = `NSApplication`

### 第 7 步：尝试编译

1. 选择 scheme: **CiteTrack** → **My Mac**
2. 按 **⌘B** 或点击 **Product → Build**

如果有编译错误，继续下一步调试。

---

## 🐛 编译调试常见问题

### 问题 1: 找不到 Sparkle.framework

**症状**：
```
Module 'Sparkle' not found
```

**解决**：
1. 检查 **Build Settings → Framework Search Paths**
2. 确保包含：`$(PROJECT_DIR)/Frameworks`
3. 确认 `Frameworks/Sparkle.framework` 文件存在

### 问题 2: 代码签名错误

**症状**：
```
Code signing "CiteTrack.app" failed
```

**解决**：
1. 选择 target → **Signing & Capabilities**
2. 暂时设置 **Automatically manage signing** 为开启
3. 选择您的开发团队，或
4. 对于本地调试，可以暂时使用 **Sign to Run Locally**

### 问题 3: 缺少某些类型或函数

**症状**：
```
Cannot find type 'SomeType' in scope
```

**解决**：
1. 可能是文件没有正确添加到 target
2. 在项目导航器中选择该文件
3. 查看右侧的 **File Inspector**
4. 确保 **Target Membership** 中 **CiteTrack** 被勾选

### 问题 4: CoreData 模型问题

**症状**：
```
Failed to load model named 'CitationTrackingModel'
```

**解决**：
1. 确保 `.xcdatamodeld` 文件夹被正确添加
2. 在项目中找到该文件，确认 Target Membership

### 问题 5: AppKit vs SwiftUI 冲突

**症状**：
```
Cannot find 'NSApplication' in scope
```

**解决**：
1. 在文件顶部添加：
   ```swift
   import AppKit
   ```

2. 或者，如果项目是 SwiftUI，需要调整代码结构

---

## 🚀 运行和调试

### 运行应用

1. 确保 scheme 选择为 **CiteTrack** 和 **My Mac**
2. 按 **⌘R** 或点击 **Product → Run**
3. 应用将启动，调试控制台会显示输出

### 设置断点

1. 在代码行号左侧点击，设置蓝色断点
2. 运行应用（⌘R）
3. 当执行到断点时会暂停
4. 使用调试工具查看变量值

### 查看日志

1. 运行应用时，底部会显示调试区域
2. 点击右上角的 **Console** 按钮查看输出
3. 使用 `print()` 或 `NSLog()` 输出调试信息

### 调试快捷键

- **⌘R**: 运行（Run）
- **⌘B**: 构建（Build）
- **⌘.**: 停止运行
- **⌘\\**: 设置/移除断点
- **F6**: 单步跳过（Step Over）
- **F7**: 单步进入（Step Into）
- **F8**: 继续执行（Continue）

---

## 💡 额外提示

### 使用不同的 main 文件

您有三个 main 文件：
- `main.swift` - 基础版本
- `main_localized.swift` - 多语言版本
- `main_v1.1.3.swift` - v1.1.3 版本

**使用特定版本**：
1. 在项目中找到不想使用的 main 文件
2. 取消勾选 **Target Membership → CiteTrack**
3. 只保留一个 main 文件勾选

### 添加图标

1. 在 **Assets.xcassets** 中，选择 **AppIcon**
2. 或者，直接拖入 `.icns` 文件到 project

### 配置启动参数

1. **Product → Scheme → Edit Scheme...**
2. 选择 **Run** → **Arguments**
3. 添加 **Environment Variables** 或 **Arguments Passed On Launch**

---

## 📊 预期结果

完成所有步骤后，您应该能够：
- ✅ 成功编译项目（无错误）
- ✅ 运行应用并看到界面
- ✅ 在调试器中设置断点
- ✅ 查看 console 输出
- ✅ 使用 Xcode 的所有调试功能

---

## 🆘 如果还有问题

1. **查看完整错误信息**：在 Xcode 中点击错误行，查看完整描述
2. **清理构建**：**Product → Clean Build Folder** (⌘⇧K)
3. **重启 Xcode**：有时 Xcode 缓存会导致问题
4. **检查文件路径**：确保所有文件路径正确

需要更具体的帮助？请提供：
- 具体的错误信息
- 错误发生的文件和行号
- 当前的配置截图

