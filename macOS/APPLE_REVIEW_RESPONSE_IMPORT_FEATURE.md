# Apple 审核回复 - 导入功能说明和示例文件

## 回复模板（英文）

```
Thank you for your review.

I understand you need to test the import feature. CiteTrack supports importing citation tracking data from JSON files. I've prepared a sample file for you to test this functionality.

**Sample Import File:**
I've attached a sample JSON file (sample_import_data.json) that contains:
- Demo scholar ID: kukA0LcAAAAJ
- Sample citation history data showing tracking over time
- Compatible with the app's import format

**How to Test the Import Feature:**

1. Launch the app
2. Open Settings (from the menu bar or main window)
3. Go to the "Data Management" section
4. Click "Import from File" or "Import Citation Data"
5. Select the sample_import_data.json file
6. The app will:
   - Import the scholar (kukA0LcAAAAJ) into the app
   - Import the citation history data
   - Display a success message showing how many scholars and history records were imported
7. After import:
   - The scholar will appear in the main list
   - You can click on the scholar to view the citation history chart
   - The chart will show the tracking data over time (from 1400 to 1500 citations)

**Sample File Format:**
The import file is a JSON file containing:
- "scholars": Array of scholar information (ID, name, citation count)
- "citationHistory": Array of historical citation data points
- Each history entry includes: scholarId, citationCount, and timestamp

**Where to Get the Sample File:**
The sample file is available at:
[You can provide a link to where you host the file, or attach it in the reply]

Alternatively, you can create a test file by:
1. Using the app's export feature to export data
2. Modifying the exported file with the demo scholar ID (kukA0LcAAAAJ)

**Tracking Feature:**
The app tracks citation data by:
1. Fetching current citation count from Google Scholar (https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en)
2. Automatically saving citation data to history when it changes
3. Displaying historical trends in charts
4. Allowing export/import of tracking data

The import feature allows users to:
- Restore previously exported data
- Sync data between devices
- Import data from iOS version of the app

Thank you for your attention.
```

## 回复模板（中文）

```
感谢您的审核。

我理解您需要测试导入功能。CiteTrack 支持从 JSON 文件导入引用跟踪数据。我已经为您准备了一个示例文件来测试此功能。

**示例导入文件：**
我已经附加了一个示例 JSON 文件（sample_import_data.json），其中包含：
- 演示学者 ID：kukA0LcAAAAJ
- 示例引用历史数据，显示随时间变化的跟踪
- 与应用导入格式兼容

**如何测试导入功能：**

1. 启动应用
2. 打开设置（从菜单栏或主窗口）
3. 转到"数据管理"部分
4. 点击"从文件导入"或"导入引用数据"
5. 选择 sample_import_data.json 文件
6. 应用将：
   - 将学者（kukA0LcAAAAJ）导入到应用中
   - 导入引用历史数据
   - 显示成功消息，显示导入了多少位学者和历史记录
7. 导入后：
   - 学者将出现在主列表中
   - 您可以点击学者查看引用历史图表
   - 图表将显示随时间变化的跟踪数据（从 1400 到 1500 次引用）

**示例文件格式：**
导入文件是一个 JSON 文件，包含：
- "scholars"：学者信息数组（ID、姓名、引用数）
- "citationHistory"：历史引用数据点数组
- 每个历史条目包括：scholarId、citationCount 和 timestamp

**如何获取示例文件：**
示例文件可在以下位置获取：
[您可以提供文件托管链接，或在回复中附加文件]

或者，您可以通过以下方式创建测试文件：
1. 使用应用的导出功能导出数据
2. 使用演示学者 ID（kukA0LcAAAAJ）修改导出的文件

**跟踪功能：**
应用通过以下方式跟踪引用数据：
1. 从 Google Scholar 获取当前引用数（https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en）
2. 当引用数发生变化时自动保存到历史记录
3. 在图表中显示历史趋势
4. 允许导出/导入跟踪数据

导入功能允许用户：
- 恢复之前导出的数据
- 在设备之间同步数据
- 从 iOS 版本的应用导入数据

感谢您的关注。
```

## 快速回复（可直接复制 - 英文）

```
Thank you for your review.

I've prepared a sample import file for testing the import feature. The file contains demo scholar ID (kukA0LcAAAAJ) with sample citation tracking data.

**To test the import feature:**

1. Launch the app
2. Open Settings → Data Management
3. Click "Import from File"
4. Select the sample_import_data.json file
5. The app will import the scholar and citation history
6. View the imported data in the main list and charts

**Sample file contents:**
- Scholar ID: kukA0LcAAAAJ
- Citation history: 6 data points showing tracking from 1400 to 1500 citations over time

**File location:**
The sample file (sample_import_data.json) is attached to this message. You can also download it from [provide link if hosting online].

**Tracking feature:**
The app tracks citations by fetching data from Google Scholar (https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en) and automatically saving changes to history. The import feature allows restoring exported data or syncing between devices.

Thank you.
```

## 如何提供示例文件

### 选项 1：在回复中附加文件（推荐）

1. 在 App Store Connect 的回复界面
2. 点击"附加文件"或"Attach File"
3. 选择 `sample_import_data.json` 文件
4. 发送回复

### 选项 2：托管在可访问的位置

1. 将 `sample_import_data.json` 上传到：
   - GitHub Gist
   - 你的网站
   - 云存储服务（Dropbox、Google Drive 等，设置为公开）
2. 在回复中提供直接下载链接

### 选项 3：在回复中直接提供 JSON 内容

如果无法附加文件，可以在回复中直接粘贴 JSON 内容，并说明审核人员可以：
1. 复制 JSON 内容
2. 保存为 .json 文件
3. 使用应用导入

## 文件说明

**文件名**: `sample_import_data.json`

**包含内容**:
- 1 位学者（ID: kukA0LcAAAAJ）
- 6 条引用历史记录
- 显示从 1400 到 1500 次引用的跟踪趋势
- 时间跨度：2025-11-20 到 2025-11-25

**用途**:
- 测试导入功能
- 验证数据格式兼容性
- 演示跟踪功能如何工作

## 重要提示

1. ✅ **提供示例文件**：确保审核人员可以访问示例文件
2. ✅ **详细说明**：提供清晰的测试步骤
3. ✅ **说明格式**：解释文件格式和内容
4. ✅ **强调功能**：说明导入功能的作用和用途


