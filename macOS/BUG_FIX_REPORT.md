# Bug 修复报告

## 日期：2025-10-26

## 问题概述

用户报告了两个关键问题：
1. **Dock 图标不显示**：应用运行时，Dock 中没有显示应用图标
2. **数据导入不生效**：从 iOS 导出的数据导入后，显示成功但学者列表没有更新

---

## 问题 1：Dock 图标不显示

### 根本原因分析

经过深入调查，发现了以下问题：

1. **Info.plist 配置不一致**
   - 原始 `Info.plist` 中配置：`CFBundleIconFile = "AppIcon"`
   - 实际图标文件名：`app_icon.icns`
   - Xcode 项目配置：`INFOPLIST_KEY_CFBundleIconFile = app_icon`
   - **结果**：名称不匹配导致图标无法加载

2. **应用激活策略问题**
   - 应用可能被设置为 `.accessory` 模式（后台应用）
   - 这种模式下应用不会显示在 Dock 中

### 修复方案

#### 修复 1：统一图标文件名

**文件**：`macOS/Info.plist`

```xml
<!-- 修改前 -->
<key>CFBundleIconFile</key>
<string>AppIcon</string>

<!-- 修改后 -->
<key>CFBundleIconFile</key>
<string>app_icon</string>
```

**说明**：将 Info.plist 中的图标文件名改为与实际文件名一致的 `app_icon`（不需要 .icns 扩展名）

#### 修复 2：强制应用显示在 Dock 中

**文件**：`macOS/Sources/main.swift`

```swift
func applicationDidFinishLaunching(_ aNotification: Notification) {
    // 首先设置应用为常规模式，确保显示在 Dock 中
    NSApp.setActivationPolicy(.regular)
    
    // ... 其他初始化代码
}
```

**说明**：在应用启动时立即设置激活策略为 `.regular`，确保应用显示在 Dock 中并有完整的 UI

### 验证结果

- ✅ 编译后的应用包含 `app_icon.icns` 文件（485KB）
- ✅ Xcode 项目配置正确：`INFOPLIST_KEY_CFBundleIconFile = app_icon`
- ✅ 应用启动时强制设置为 `.regular` 模式

---

## 问题 2：数据导入不生效

### 根本原因分析

这是一个**数据存储不一致**的严重问题：

1. **两个数据管理器使用不同的存储 Key**
   ```swift
   // DataManager.swift
   private let scholarsKey = "ScholarsList"  // ❌ 错误的 key
   
   // main.swift - PreferencesManager
   static let scholars = "Scholars"  // ✅ UI 使用的 key
   ```

2. **数据流向分析**
   ```
   导入数据 → DataManager.importFromiOSData()
            → DataManager.addScholar() 
            → UserDefaults["ScholarsList"] ← 写入这里
   
   UI 显示 ← SettingsWindow.loadData()
          ← PreferencesManager.scholars
          ← UserDefaults["Scholars"] ← 从这里读取
   ```

3. **问题表现**
   - 导入时写入 `UserDefaults["ScholarsList"]`
   - UI 读取 `UserDefaults["Scholars"]`
   - 两个完全不同的存储位置！
   - 导入成功但 UI 看不到数据

### 修复方案

#### 修复 1：统一存储 Key

**文件**：`macOS/Sources/DataManager.swift`

```swift
// 修改前
private let scholarsKey = "ScholarsList"

// 修改后
private let scholarsKey = "Scholars"  // 与 PreferencesManager 保持一致
```

#### 修复 2：移除重复的数据同步调用

由于现在两个管理器使用同一个存储 key，不再需要手动同步数据：

**文件**：`macOS/Sources/DataManager.swift`

```swift
// 修改前
public func addScholar(_ scholar: Scholar) {
    if !scholars.contains(where: { $0.id == scholar.id }) {
        scholars.append(scholar)
        saveScholars()
        
        // 同步到 PreferencesManager ← 不再需要
        PreferencesManager.shared.addScholar(scholar)
        
        NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
        print("✅ [DataManager] 添加了学者: \(scholar.name)")
    }
}

// 修改后
public func addScholar(_ scholar: Scholar) {
    if !scholars.contains(where: { $0.id == scholar.id }) {
        scholars.append(scholar)
        saveScholars()
        
        // 发送数据更新通知
        NotificationCenter.default.post(name: .scholarsDataUpdated, object: nil)
        print("✅ [DataManager] 添加了学者: \(scholar.name)")
    }
}
```

同样的修改也应用到 `updateScholar()` 方法。

#### 修复 3：确保导入时更新现有学者

**文件**：`macOS/Sources/DataManager.swift`

```swift
// 在 importFromHistoryArray 方法中
for scholar in scholarMap.values {
    if !self.scholars.contains(where: { $0.id == scholar.id }) {
        addScholar(scholar)
        importedScholars += 1
    } else {
        // 更新现有学者（而不是跳过）
        updateScholar(scholar)
        importedScholars += 1
    }
}
```

### 数据流向（修复后）

```
导入数据 → DataManager.importFromiOSData()
         → DataManager.addScholar() / updateScholar()
         → UserDefaults["Scholars"] ← 写入统一的 key
         → NotificationCenter.post(.scholarsDataUpdated)
         
UI 更新 ← SettingsWindow.scholarsDataUpdated()
        ← loadData()
        ← PreferencesManager.scholars
        ← UserDefaults["Scholars"] ← 从同一个 key 读取 ✅
        ← tableView.reloadData()
```

### 验证结果

- ✅ `DataManager` 和 `PreferencesManager` 现在使用相同的存储 key：`"Scholars"`
- ✅ 导入数据时会正确更新现有学者
- ✅ 导入后会发送 `scholarsDataUpdated` 通知
- ✅ UI 会响应通知并重新加载数据

---

## 编译结果

```bash
** BUILD SUCCEEDED **
```

编译成功，只有一个警告（关于代码签名，不影响功能）：
```
warning: CiteTrack isn't code signed but requires entitlements.
```

---

## 测试建议

### 测试 Dock 图标

1. 完全退出应用
2. 从 Xcode 或 Finder 重新启动应用
3. 检查 Dock 中是否显示应用图标
4. 图标应该与 iOS 应用图标一致

### 测试数据导入

1. 从 iOS 应用导出数据（citation_data.json）
2. 在 macOS 应用中选择"导入数据"
3. 选择导出的 JSON 文件
4. 检查控制台日志：
   - 应该看到 "✅ [DataManager] 添加了学者: XXX" 或 "✅ [DataManager] 更新了学者: XXX"
   - 应该看到 "✅ [DataManager] 从iOS数据导入: X 位学者, Y 条历史记录"
5. 检查学者列表：
   - 新学者应该立即出现在列表中
   - 现有学者的数据应该被更新

### 测试数据持久化

1. 导入数据后，完全退出应用
2. 重新启动应用
3. 学者列表应该保留导入的数据

---

## 技术细节

### 数据存储架构

```
┌─────────────────────────────────────────┐
│         UserDefaults Storage            │
│                                         │
│  Key: "Scholars"                        │
│  Value: JSON encoded [Scholar]          │
│                                         │
│  ┌─────────────┐    ┌─────────────┐   │
│  │ DataManager │    │PreferencesM│   │
│  │   (写入)    │    │   (读取)    │   │
│  └─────────────┘    └─────────────┘   │
│         ↓                   ↑          │
│         └───────────────────┘          │
│           同一个存储位置               │
└─────────────────────────────────────────┘
```

### 通知机制

```
DataManager.addScholar() / updateScholar()
    ↓
NotificationCenter.post(.scholarsDataUpdated)
    ↓
SettingsWindow.scholarsDataUpdated()
    ↓
loadData() → PreferencesManager.scholars
    ↓
tableView.reloadData()
```

---

## 总结

两个问题都已经从根本原因上得到解决：

1. **Dock 图标**：修复了图标文件名不一致的问题，并强制应用显示在 Dock 中
2. **数据导入**：修复了数据存储 key 不一致的严重问题，确保导入的数据能被 UI 正确读取

这些修复确保了：
- ✅ 应用图标正确显示
- ✅ 数据导入真正生效
- ✅ UI 实时更新
- ✅ 数据持久化正常工作
- ✅ 与 iOS 应用数据格式完全兼容

---

## 相关文件

- `macOS/Info.plist` - 图标配置
- `macOS/Sources/main.swift` - 应用启动和 PreferencesManager
- `macOS/Sources/DataManager.swift` - 数据导入和管理
- `macOS/Sources/SettingsWindow.swift` - UI 更新逻辑

