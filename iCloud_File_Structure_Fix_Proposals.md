# iCloud文件结构修复方案

## 🔴 当前存在的问题

### 1. 文件名命名混乱
- ❌ `ios_data.json` 在macOS中也被使用，但命名暗示这是iOS专用
- ❌ 文件用途不清晰，用户无法理解每个文件的作用

### 2. 配置内容不一致
**iOS的`ios_data.json`包含**:
```json
{
  "settings": {
    "updateInterval": ...,
    "notificationsEnabled": ...,
    "language": ...,
    "theme": ...,
    "iCloudDriveFolderEnabled": ...
  },
  "refreshData": {...},
  "firstInstallDate": "..."
}
```

**macOS的`ios_data.json`包含**:
```json
{
  "settings": {
    "updateInterval": ...,
    "showInDock": ...,
    "showInMenuBar": ...,
    "launchAtLogin": ...,
    "iCloudSyncEnabled": ...,
    "language": ...
  }
}
```
- ❌ 配置项完全不同，无法互相导入
- ❌ macOS缺少iOS的配置（notificationsEnabled, theme, refreshData等）
- ❌ iOS缺少macOS的配置（showInDock, showInMenuBar等）

### 3. 导入逻辑不一致
- ❌ iOS: 自动导入配置（从`ios_data.json`）
- ❌ macOS: 创建`ios_data.json`但不会自动导入配置
- ❌ macOS的手动导入只读取`citation_data.json`，忽略配置

### 4. 文件格式不统一
- ❌ `citation_data.json`: 纯历史记录数组
- ❌ `ios_data.json`: 配置格式（iOS和macOS不同）
- ❌ `CiteTrack_sync.json`: 统一格式（包含citationHistory字段）
- ❌ 导入时需要猜测格式

---

## ✅ 修复方案

### 方案1: 统一文件格式 + 分离平台配置（推荐）

#### 文件结构
```
iCloud.com.citetrack.CiteTrack/Documents/
├── data.json              # 统一的数据文件（跨平台）
├── config_ios.json        # iOS专用配置
├── config_macos.json      # macOS专用配置
└── .keep                  # 占位文件（iOS）
```

#### 文件内容

**`data.json`** - 统一的数据格式（iOS和macOS完全一致）
```json
{
  "version": "2.0",
  "exportDate": "2024-01-01T12:00:00Z",
  "scholars": [
    {
      "id": "USER_ID",
      "name": "学者名称",
      "citations": 1234,
      "lastUpdated": "2024-01-01T12:00:00Z"
    }
  ],
  "citationHistory": [
    {
      "scholarId": "USER_ID",
      "scholarName": "学者名称",
      "timestamp": "2024-01-01T12:00:00Z",
      "citationCount": 1234
    }
  ]
}
```

**`config_ios.json`** - iOS配置
```json
{
  "version": "2.0",
  "platform": "ios",
  "settings": {
    "updateInterval": 86400,
    "notificationsEnabled": true,
    "language": "zh-Hans",
    "theme": "light",
    "iCloudDriveFolderEnabled": true,
    "autoUpdateEnabled": true,
    "autoUpdateFrequency": "daily"
  },
  "refreshData": {...},
  "firstInstallDate": "..."
}
```

**`config_macos.json`** - macOS配置
```json
{
  "version": "2.0",
  "platform": "macos",
  "settings": {
    "updateInterval": 86400,
    "showInDock": true,
    "showInMenuBar": true,
    "launchAtLogin": false,
    "iCloudSyncEnabled": true,
    "iCloudDriveFolderEnabled": true,
    "language": "zh-Hans"
  }
}
```

#### 优点
- ✅ 文件用途清晰
- ✅ 平台配置分离，互不干扰
- ✅ 数据文件统一，完全兼容
- ✅ 易于扩展和维护

#### 缺点
- ⚠️ 需要迁移现有数据
- ⚠️ 需要修改导入导出逻辑

---

### 方案2: 保持向后兼容 + 统一命名

#### 文件结构
```
iCloud.com.citetrack.CiteTrack/Documents/
├── citation_data.json     # 历史数据（保持原名）
├── app_config.json        # 统一配置（重命名自ios_data.json）
└── .keep                  # 占位文件（iOS）
```

#### 文件内容

**`citation_data.json`** - 保持不变（向后兼容）
```json
[
  {
    "scholarId": "USER_ID",
    "scholarName": "学者名称",
    "timestamp": "2024-01-01T12:00:00Z",
    "citationCount": 1234
  }
]
```

**`app_config.json`** - 统一配置格式
```json
{
  "version": "2.0",
  "exportDate": "2024-01-00T12:00:00Z",
  "platform": "ios|macos",
  "settings": {
    // iOS设置
    "updateInterval": 86400,
    "notificationsEnabled": true,  // iOS only
    "theme": "light",               // iOS only
    "iCloudDriveFolderEnabled": true,
    
    // macOS设置
    "showInDock": true,              // macOS only
    "showInMenuBar": true,           // macOS only
    "launchAtLogin": false,          // macOS only
    
    // 通用设置
    "language": "zh-Hans"
  },
  "refreshData": {...},             // iOS only
  "firstInstallDate": "..."          // iOS only
}
```

#### 优点
- ✅ 保持向后兼容
- ✅ 文件名更通用（`app_config.json`）
- ✅ 配置统一在一个文件，但平台特定字段分离
- ✅ 迁移成本低

#### 缺点
- ⚠️ 配置文件中包含平台特定字段，可能混乱
- ⚠️ 导入时需要判断平台

---

### 方案3: 单一统一文件（最简单）

#### 文件结构
```
iCloud.com.citetrack.CiteTrack/Documents/
├── CiteTrack_Backup.json  # 统一备份文件（包含所有数据）
└── .keep                  # 占位文件（iOS）
```

#### 文件内容

**`CiteTrack_Backup.json`** - 完整备份格式
```json
{
  "version": "2.0",
  "exportDate": "2024-01-01T12:00:00Z",
  "platform": "ios|macos",
  
  "scholars": [...],
  "citationHistory": [...],
  
  "settings_ios": {
    "updateInterval": 86400,
    "notificationsEnabled": true,
    "theme": "light",
    ...
  },
  "settings_macos": {
    "updateInterval": 86400,
    "showInDock": true,
    "showInMenuBar": true,
    ...
  },
  
  "refreshData": {...},        // iOS only
  "firstInstallDate": "..."     // iOS only
}
```

#### 优点
- ✅ 只有一个文件，最简单
- ✅ 完整备份，包含所有数据
- ✅ 无需猜测文件格式

#### 缺点
- ⚠️ 每次同步都要读写整个文件
- ⚠️ 不利于增量更新
- ⚠️ 文件可能很大

---

## 🎯 推荐方案：方案1（统一文件格式 + 分离平台配置）

### 实施步骤

#### 阶段1: 数据迁移
1. 检测现有文件格式
2. 自动迁移到新格式
3. 保留旧文件作为备份

#### 阶段2: 统一导出逻辑
```swift
// iOS和macOS都使用相同的导出格式
func exportData() -> Data {
    return unifiedDataFormat(
        scholars: scholars,
        citationHistory: history,
        version: "2.0"
    )
}
```

#### 阶段3: 统一导入逻辑
```swift
// iOS和macOS都能导入相同的数据格式
func importData(_ data: Data) {
    let unified = parseUnifiedFormat(data)
    importScholars(unified.scholars)
    importHistory(unified.citationHistory)
}

// 平台配置单独处理
func importConfig(_ platform: Platform) {
    let config = loadConfig(for: platform)
    applySettings(config.settings)
}
```

#### 阶段4: 更新文档
- 更新用户文档
- 更新开发文档
- 添加迁移指南

---

## 📋 实施检查清单

### 代码修改
- [ ] 统一`data.json`格式（iOS和macOS）
- [ ] 分离`config_ios.json`和`config_macos.json`
- [ ] 更新导出逻辑（两个平台）
- [ ] 更新导入逻辑（两个平台）
- [ ] 添加数据迁移逻辑
- [ ] 更新文件URL定义

### 测试
- [ ] iOS导出 → macOS导入
- [ ] macOS导出 → iOS导入
- [ ] 旧格式文件自动迁移
- [ ] 配置导入/导出正确性
- [ ] 数据完整性验证

### 文档
- [ ] 更新用户指南
- [ ] 更新开发文档
- [ ] 添加迁移说明

---

## 🔄 迁移策略

### 自动迁移（推荐）
1. 应用启动时检测旧格式文件
2. 自动转换为新格式
3. 保留旧文件（重命名为`.backup`）
4. 用户确认后删除旧文件

### 手动迁移（可选）
1. 提供迁移工具
2. 用户手动触发迁移
3. 迁移后验证数据完整性

---

## 📊 方案对比

| 特性 | 方案1 | 方案2 | 方案3 |
|------|-------|-------|-------|
| 文件清晰度 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| 向后兼容 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| 实施复杂度 | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 维护成本 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| 扩展性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |

---

## 💡 建议

**推荐使用方案1**，因为：
1. 文件用途最清晰，易于维护
2. 平台配置分离，互不干扰
3. 数据格式统一，完全兼容
4. 长期维护成本最低

如果需要快速修复，可以先实施方案2（保持向后兼容），然后逐步迁移到方案1。

