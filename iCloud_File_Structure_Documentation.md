# iCloud文件夹文件结构说明

## 📁 文件夹位置

**iCloud容器路径**: `iCloud.com.citetrack.CiteTrack/Documents/`
- 这是用户在iCloud Drive中看到的"CiteTrack"文件夹
- iOS和macOS使用相同的容器路径，确保数据可以跨平台同步

---

## 📄 主要数据文件

### 1. `citation_data.json` - 引用历史数据

**用途**: 存储所有学者的引用历史记录

**格式**: JSON数组，每个元素是一条历史记录
```json
[
  {
    "scholarId": "USER_ID",
    "scholarName": "学者名称",
    "timestamp": "2024-01-01T12:00:00Z",
    "citationCount": 1234
  },
  ...
]
```

**内容说明**:
- `scholarId`: Google Scholar用户ID
- `scholarName`: 学者显示名称
- `timestamp`: ISO8601格式的时间戳
- `citationCount`: 该时间点的引用数

**导出来源**:
- **iOS**: `iCloudSyncManager.makeExportJSONData()` → 从`DataManager.shared.getHistory()`获取历史记录
- **macOS**: `DataManager.exportToiOSFormat()` → 从Core Data获取历史记录

**导入处理**:
- **iOS**: `iCloudSyncManager.importFromFile()` → 调用`DataManager.importFromiOSData()`
- **macOS**: `SettingsWindow.importData()` → 调用`DataManager.importFromiOSData()`

**兼容性**: ✅ iOS和macOS完全兼容，可以互相导入导出

---

### 2. `ios_data.json` - 应用配置数据

**用途**: 存储应用设置、刷新数据、首次安装日期等配置信息

**格式**: JSON对象
```json
{
  "version": "1.1",
  "exportDate": "2024-01-01T12:00:00Z",
  "settings": {
    "updateInterval": 86400,
    "notificationsEnabled": true,
    "language": "zh-Hans",
    "theme": "light",
    "iCloudDriveFolderEnabled": true
  },
  "refreshData": {
    // 刷新行为相关数据
  },
  "firstInstallDate": "2024-01-01T12:00:00Z"
}
```

**内容说明**:
- `version`: 导出格式版本
- `exportDate`: 导出时间
- `settings`: 应用设置（更新间隔、通知、语言、主题等）
- `refreshData`: 刷新行为数据（从`exportRefreshDataFromBehavior()`获取）
- `firstInstallDate`: 首次安装日期（用于跨重装恢复）

**导出来源**:
- **iOS**: `iCloudSyncManager.makeCurrentAppData()` → 从`SettingsManager.shared`获取设置
- **macOS**: `iCloudSyncManager.makeCurrentAppData()` → 从`PreferencesManager.shared`获取设置

**导入处理**:
- **iOS**: `iCloudSyncManager.importFromUnifiedData()` → 解析并应用设置
- **macOS**: 目前未实现自动导入配置（但文件会被创建）

**注意**: 这个文件主要用于iOS，macOS也会创建但不会自动导入配置

---

## 🔧 辅助文件

### 3. `.keep` - 占位文件

**用途**: 确保iCloud文件夹在Files应用中可见

**内容**: 简单的文本文件，内容为"keep"

**创建时机**: 
- iOS: `createiCloudDriveFolder()` 或 `bootstrapContainerIfPossible()`
- macOS: 不创建此文件

---

### 4. `.citetrack_app_info` - 应用标识文件

**用途**: 帮助系统识别文件夹属于CiteTrack应用

**格式**: JSON对象
```json
{
  "app_name": "CiteTrack",
  "bundle_id": "com.citetrack.CiteTrack",
  "version": "1.0.1",
  "created_at": "2024-01-01T12:00:00Z"
}
```

**创建时机**: 
- iOS: `createiCloudDriveFolder()` 时创建
- macOS: 不创建此文件

---

### 5. `CiteTrack_sync.json` - 长期同步镜像文件（容器内）

**用途**: 在应用容器内创建镜像文件，用于长期同步

**位置**: `iCloud.com.citetrack.CiteTrack/Documents/CiteTrack_sync.json`（容器内，用户不可见）

**格式**: 与`citation_data.json`相同的格式，但包含完整的应用数据（使用`makeAppDataJSON()`）

**创建时机**: 
- iOS: `performImmediateSync()` 时在容器内创建镜像
- macOS: 不创建此文件

---

## 🔄 导入导出流程

### iOS导出流程

1. **立即同步** (`performImmediateSync()`):
   - 创建`citation_data.json`（使用`makeExportJSONData()`）
   - 创建`ios_data.json`（使用`makeCurrentAppData()`）
   - 在容器内创建`CiteTrack_sync.json`镜像

2. **CloudKit导出** (`exportUsingCloudKit()`):
   - 使用`makeAppDataJSON()`创建统一格式
   - 通过CloudKit同步服务保存

### macOS导出流程

1. **立即同步** (`exportUsingCloudKit()`):
   - 调用`DataManager.exportToiOSFormat()`生成数据
   - 写入`citation_data.json`
   - 创建`ios_data.json`（使用`makeCurrentAppData()`）

### 导入流程

1. **iOS导入**:
   - 优先读取`citation_data.json`（历史记录数组格式）
   - 如果不存在，尝试读取`ios_data.json`中的统一格式
   - 调用`DataManager.importFromiOSData()`处理

2. **macOS导入**:
   - 用户手动选择文件（通过文件选择器）
   - 调用`DataManager.importFromiOSData()`处理
   - 支持多种格式：iOS标准格式、历史记录数组、统一格式

---

## ⚠️ 当前问题

### 1. 文件命名混乱
- `ios_data.json` 在macOS中也被使用，但命名暗示这是iOS专用
- 建议：统一命名为 `app_config.json` 或 `config.json`

### 2. 配置导入不一致
- iOS会自动导入配置（设置、刷新数据等）
- macOS创建了`ios_data.json`但不会自动导入配置
- 建议：macOS也应该支持配置导入

### 3. 文件格式不统一
- `citation_data.json` 是纯历史记录数组
- `ios_data.json` 可能包含统一格式（包含citationHistory字段）
- `CiteTrack_sync.json` 是完整的统一格式
- 建议：统一使用一种格式，或者明确区分用途

### 4. 导入逻辑复杂
- `DataManager.importFromiOSData()` 需要尝试解析多种格式
- 建议：明确文件格式，减少格式猜测

---

## ✅ 建议的改进方案

### 方案1: 统一文件格式

**文件结构**:
- `citation_data.json`: 纯历史记录数组（保持向后兼容）
- `app_config.json`: 应用配置（重命名自`ios_data.json`）
- `unified_data.json`: 统一格式（包含所有数据，用于完整备份）

### 方案2: 明确文件用途

**文件结构**:
- `data.json`: 学者数据 + 历史记录（统一格式）
- `config.json`: 应用配置（设置、刷新数据等）
- `backup.json`: 完整备份（包含所有数据）

### 方案3: 版本化文件

**文件结构**:
- `v1_citation_data.json`: 历史记录（版本1格式）
- `v1_app_config.json`: 应用配置（版本1格式）
- `metadata.json`: 元数据（版本信息、文件列表等）

---

## 📊 数据流向图

```
iOS导出:
DataManager → makeExportJSONData() → citation_data.json
SettingsManager → makeCurrentAppData() → ios_data.json

macOS导出:
DataManager → exportToiOSFormat() → citation_data.json
PreferencesManager → makeCurrentAppData() → ios_data.json

iOS导入:
citation_data.json → importFromiOSData() → DataManager
ios_data.json → importFromUnifiedData() → SettingsManager + DataManager

macOS导入:
用户选择文件 → importFromiOSData() → DataManager
```

---

## 🔍 代码位置参考

### iOS
- **导出**: `iOS/CiteTrack/iCloudSyncManager.swift`
  - `makeExportJSONData()`: 行1306-1336
  - `makeCurrentAppData()`: 行1126-1144
  - `performExport()`: 行1086-1096

- **导入**: `iOS/CiteTrack/iCloudSyncManager.swift`
  - `importFromFile()`: 行950-1000
  - `importFromUnifiedData()`: 行1200+

### macOS
- **导出**: `macOS/Sources/iCloudSyncManager.swift`
  - `exportUsingCloudKit()`: 行24-41
  - `exportCitationData()`: 行186-199
  - `exportAppConfig()`: 行223-232

- **导入**: `macOS/Sources/SettingsWindow.swift`
  - `importData()`: 行287-318
  - `DataManager.importFromiOSData()`: 行230-255

### 共享
- **DataManager**: `macOS/Sources/DataManager.swift`
  - `exportToiOSFormat()`: 行460-490
  - `importFromiOSData()`: 行230-255

