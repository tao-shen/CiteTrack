# iCloud按钮/操作与文件映射关系

## 📱 iOS操作

### 1. **"立即同步"按钮** (`sync_now`)
**触发方法**: `iCloudSyncManager.performImmediateSync()` → `exportUsingCloudKit()`

**写入文件**:
1. **`citation_data.json`** (在 `iCloud.com.citetrack.CiteTrack/Documents/`)
   - **内容**: 历史记录数组
   - **格式**: `[[String: Any]]`
   - **生成方法**: `makeExportJSONData()`
   - **数据来源**: `DataManager.shared.getHistory()` - 所有学者的引用历史
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

2. **`ios_data.json`** (在 `iCloud.com.citetrack.CiteTrack/Documents/`)
   - **内容**: 应用配置数据
   - **格式**: `[String: Any]`
   - **生成方法**: `makeCurrentAppData()`
   - **数据来源**: `SettingsManager.shared` - 应用设置
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
     "refreshData": {...},
     "firstInstallDate": "..."
   }
   ```

3. **`CiteTrack_sync.json`** (在容器内，用户不可见)
   - **内容**: 统一格式完整数据
   - **格式**: `[String: Any]` (包含citationHistory字段)
   - **生成方法**: `makeAppDataJSON(exportPayload:)`
   - **数据来源**: 合并`makeCurrentAppData()`和`makeExportJSONData()`
   ```json
   {
     "version": "1.1",
     "exportDate": "...",
     "settings": {...},
     "refreshData": {...},
     "citationHistory": [...]
   }
   ```

**代码位置**: `iOS/CiteTrack/iCloudSyncManager.swift`
- `performImmediateSync()`: 行165-232
- `performExport()`: 行1086-1096
- `makeExportJSONData()`: 行1306-1336
- `makeCurrentAppData()`: 行1126-1144

---

### 2. **"从文件导入"按钮** (`manual_import_file`)
**触发方法**: `iCloudSyncManager.showFilePicker()` → `importFromFile(url:)`

**读取文件**: 
- 用户通过文件选择器选择的任意JSON文件
- 支持格式：
  1. 历史记录数组格式（`citation_data.json`格式）
  2. iOS标准格式（包含scholars和citationHistory）
  3. 统一格式（包含settings和citationHistory）

**处理逻辑**: `importFromFile(url:)` → `DataManager.importFromiOSData()`

**代码位置**: `iOS/CiteTrack/iCloudSyncManager.swift`
- `importFromFile()`: 行829-1007
- `importFromJSONData()`: 行1200+

---

### 3. **"导出到文件"按钮** (`export_to_device`)
**触发方法**: `exportToLocalDevice()` → `writeExportToTemporaryFile()`

**写入文件**: 
- **临时文件** (用户选择保存位置)
- **文件名**: `CiteTrack_yyyyMMdd-HHmmss_v<version>_<device>.json`
- **内容**: 历史记录数组（与`citation_data.json`相同格式）
- **生成方法**: `makeExportJSONData()`

**代码位置**: `iOS/CiteTrack/CiteTrackApp.swift`
- `exportToLocalDevice()`: 行2252-2261
- `writeExportToTemporaryFile()`: 行2264-2280

---

### 4. **首次启动自动导入** (`importConfigOnFirstLaunch()`)
**触发时机**: 应用首次启动时自动执行

**读取文件**:
1. **`citation_data.json`** (在 `iCloud.com.citetrack.CiteTrack/Documents/`)
2. **`ios_data.json`** (在 `iCloud.com.citetrack.CiteTrack/Documents/`)
3. **`CiteTrack_sync.json`** (在容器内，作为兜底)

**处理逻辑**: `performImport()` → 依次尝试读取上述文件

**代码位置**: `iOS/CiteTrack/iCloudSyncManager.swift`
- `importConfigOnFirstLaunch()`: 行34-148
- `performImport()`: 行872-1007

---

## 💻 macOS操作

### 1. **"立即同步"按钮** (`sync_now`)
**触发方法**: `SettingsWindow.performImmediateSync()` → `iCloudSyncManager.exportUsingCloudKit()`

**写入文件**:
1. **`citation_data.json`** (在 `iCloud.com.citetrack.CiteTrack/Documents/`)
   - **内容**: 历史记录数组
   - **格式**: `[[String: Any]]`
   - **生成方法**: `DataManager.exportToiOSFormat()`
   - **数据来源**: `CitationHistoryManager.shared.getAllHistory()` - 所有学者的引用历史
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

2. **`ios_data.json`** (在 `iCloud.com.citetrack.CiteTrack/Documents/`)
   - **内容**: 应用配置数据
   - **格式**: `[String: Any]`
   - **生成方法**: `makeCurrentAppData()`
   - **数据来源**: `PreferencesManager.shared` - 应用设置
   ```json
   {
     "version": "1.1",
     "exportDate": "2024-01-01T12:00:00Z",
     "settings": {
       "updateInterval": 86400,
       "showInDock": true,
       "showInMenuBar": true,
       "launchAtLogin": false,
       "iCloudSyncEnabled": true,
       "language": "zh-Hans"
     }
   }
   ```
   ⚠️ **注意**: macOS的配置与iOS不同，缺少`notificationsEnabled`, `theme`, `refreshData`, `firstInstallDate`

**代码位置**: `macOS/Sources/SettingsWindow.swift`
- `performImmediateSync()`: 行421-446
- `macOS/Sources/iCloudSyncManager.swift`
- `exportUsingCloudKit()`: 行24-41
- `exportCitationData()`: 行196-199
- `exportAppConfig()`: 行223-232
- `makeCurrentAppData()`: 行553-568

---

### 2. **"从文件导入"按钮** (`manual_import_file`)
**触发方法**: `SettingsWindow.importData()`

**读取文件**: 
- 用户通过文件选择器选择的任意JSON文件
- 支持格式：
  1. 历史记录数组格式（`citation_data.json`格式）
  2. iOS标准格式（包含scholars和citationHistory）
  3. 统一格式（包含settings和citationHistory）

**处理逻辑**: `DataManager.importFromiOSData()`

**代码位置**: `macOS/Sources/SettingsWindow.swift`
- `importData()`: 行339-368
- `macOS/Sources/DataManager.swift`
- `importFromiOSData()`: 行230-255

⚠️ **注意**: macOS不会自动导入`ios_data.json`中的配置，只导入数据

---

### 3. **"导出到文件"按钮** (`export_to_device`)
**触发方法**: `SettingsWindow.exportData()`

**写入文件**: 
- **用户选择保存位置** (通过NSSavePanel)
- **文件名**: `CiteTrack_Export_<timestamp>.json` 或 `.csv`
- **内容**: 
  - JSON格式: 所有历史记录（通过`CitationHistoryManager.shared.exportAllHistory()`）
  - CSV格式: 历史记录的CSV格式

**代码位置**: `macOS/Sources/SettingsWindow.swift`
- `exportData()`: 行304-338
- `macOS/Sources/CitationHistoryManager.swift`
- `exportAllHistory()`: 行517-537

---

## 📊 文件读写总结表

| 操作 | 平台 | 写入文件 | 文件内容 | 读取文件 |
|------|------|----------|----------|----------|
| **立即同步** | iOS | `citation_data.json`<br>`ios_data.json`<br>`CiteTrack_sync.json` | 历史记录数组<br>应用配置<br>统一格式数据 | - |
| **立即同步** | macOS | `citation_data.json`<br>`ios_data.json` | 历史记录数组<br>应用配置（macOS版） | - |
| **从文件导入** | iOS | - | - | 用户选择的JSON文件 |
| **从文件导入** | macOS | - | - | 用户选择的JSON文件 |
| **导出到文件** | iOS | 临时文件（用户选择位置） | 历史记录数组 | - |
| **导出到文件** | macOS | 用户选择位置 | 历史记录（JSON/CSV） | - |
| **首次启动导入** | iOS | - | - | `citation_data.json`<br>`ios_data.json`<br>`CiteTrack_sync.json` |

---

## 🔍 文件内容详细说明

### `citation_data.json`
- **位置**: `iCloud.com.citetrack.CiteTrack/Documents/citation_data.json`
- **格式**: JSON数组
- **内容**: 所有学者的引用历史记录
- **写入者**: 
  - iOS: `makeExportJSONData()`
  - macOS: `DataManager.exportToiOSFormat()`
- **读取者**:
  - iOS: `importFromJSONData()`
  - macOS: `DataManager.importFromiOSData()`

### `ios_data.json`
- **位置**: `iCloud.com.citetrack.CiteTrack/Documents/ios_data.json`
- **格式**: JSON对象
- **内容**: 应用配置（iOS和macOS配置不同）
- **写入者**:
  - iOS: `makeCurrentAppData()` (包含iOS特有配置)
  - macOS: `makeCurrentAppData()` (包含macOS特有配置)
- **读取者**:
  - iOS: `performImport()` (自动导入配置)
  - macOS: ❌ 不自动读取（虽然会创建此文件）

### `CiteTrack_sync.json`
- **位置**: `iCloud.com.citetrack.CiteTrack/Documents/CiteTrack_sync.json` (iOS容器内)
- **格式**: JSON对象（统一格式）
- **内容**: 完整数据（包含settings和citationHistory）
- **写入者**: iOS `makeAppDataJSON()` (仅在立即同步时)
- **读取者**: iOS `performImport()` (作为兜底导入)

---

## ⚠️ 问题总结

### 1. 配置不一致
- iOS的`ios_data.json`包含: `notificationsEnabled`, `theme`, `refreshData`, `firstInstallDate`
- macOS的`ios_data.json`包含: `showInDock`, `showInMenuBar`, `launchAtLogin`, `iCloudSyncEnabled`
- **结果**: 两个平台的配置无法互相导入

### 2. macOS不读取配置
- macOS会创建`ios_data.json`，但不会自动读取和应用配置
- **结果**: macOS用户无法从iCloud同步配置

### 3. 文件名混乱
- `ios_data.json`在macOS中也被使用，但命名暗示iOS专用
- **结果**: 用户和开发者容易混淆

### 4. 文件格式不统一
- `citation_data.json`: 纯数组
- `ios_data.json`: 配置对象
- `CiteTrack_sync.json`: 统一格式（包含citationHistory）
- **结果**: 导入时需要猜测格式

---

## 📝 代码引用位置

### iOS
- `performImmediateSync()`: `iOS/CiteTrack/iCloudSyncManager.swift:165`
- `performExport()`: `iOS/CiteTrack/iCloudSyncManager.swift:1086`
- `makeExportJSONData()`: `iOS/CiteTrack/iCloudSyncManager.swift:1306`
- `makeCurrentAppData()`: `iOS/CiteTrack/iCloudSyncManager.swift:1126`
- `importFromFile()`: `iOS/CiteTrack/iCloudSyncManager.swift:829`
- `exportToLocalDevice()`: `iOS/CiteTrack/CiteTrackApp.swift:2252`

### macOS
- `performImmediateSync()`: `macOS/Sources/SettingsWindow.swift:421`
- `exportUsingCloudKit()`: `macOS/Sources/iCloudSyncManager.swift:24`
- `exportCitationData()`: `macOS/Sources/iCloudSyncManager.swift:196`
- `exportAppConfig()`: `macOS/Sources/iCloudSyncManager.swift:223`
- `makeCurrentAppData()`: `macOS/Sources/iCloudSyncManager.swift:553`
- `importData()`: `macOS/Sources/SettingsWindow.swift:339`
- `exportData()`: `macOS/Sources/SettingsWindow.swift:304`

