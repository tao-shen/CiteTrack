# Apple 审核回复 - 托管示例文件

## 重要：文件必须托管在可访问的位置

Apple 审核团队要求示例文件必须托管在一个持续可访问的位置。以下是几种方案：

## 方案 1：GitHub Gist（推荐）

### 步骤：

1. **访问 GitHub Gist**
   - 打开 https://gist.github.com/
   - 登录你的 GitHub 账户（如果没有，需要先注册）

2. **创建新的 Gist**
   - 点击 "New gist" 或 "+" 按钮
   - 文件名：`sample_import_data.json`
   - 内容：复制 `sample_import_data.json` 的完整内容
   - **重要**：选择 "Create public gist"（公开）
   - 点击 "Create public gist"

3. **获取 Raw 链接**
   - 创建后，点击 "Raw" 按钮
   - 复制浏览器地址栏中的 URL
   - 格式类似：`https://gist.githubusercontent.com/用户名/gist_id/raw/.../sample_import_data.json`

4. **在回复中使用**
   - 在 App Store Connect 回复中提供这个 Raw 链接
   - 说明：审核人员可以直接下载文件

## 方案 2：GitHub Repository

### 步骤：

1. **创建 GitHub Repository**
   - 在 GitHub 上创建新的公开仓库
   - 例如：`citetrack-sample-data`

2. **上传文件**
   - 将 `sample_import_data.json` 上传到仓库
   - 确保仓库是公开的

3. **获取 Raw 链接**
   - 在 GitHub 上打开文件
   - 点击 "Raw" 按钮
   - 复制 URL
   - 格式：`https://raw.githubusercontent.com/用户名/仓库名/main/sample_import_data.json`

## 方案 3：你的网站

### 步骤：

1. **上传文件到你的网站**
   - 将 `sample_import_data.json` 上传到你的网站
   - 确保文件可以公开访问

2. **提供直接下载链接**
   - 格式：`https://你的网站.com/sample_import_data.json`
   - 确保链接稳定，不会失效

## 方案 4：云存储服务

### Dropbox：

1. 上传文件到 Dropbox
2. 创建共享链接
3. 将链接中的 `www.dropbox.com` 改为 `dl.dropboxusercontent.com`
4. 移除 `?dl=0`，添加 `?raw=1`

### Google Drive：

1. 上传文件到 Google Drive
2. 右键点击文件 → 获取链接
3. 设置为"知道链接的任何人"
4. 提取文件 ID，使用格式：`https://drive.google.com/uc?export=download&id=文件ID`

## 回复模板（英文）

```
Thank you for your review.

I've prepared a sample JSON file for testing the import feature. The file is hosted at a publicly accessible location and will remain available for future reviews.

**Sample Import File:**
[在这里插入文件的直接下载链接]

**File Details:**
- Filename: sample_import_data.json
- Format: JSON
- Contains: Demo scholar ID (kukA0LcAAAAJ) with citation tracking data
- 6 citation history data points showing tracking from 1400 to 1500 citations

**How to Test the Import Feature:**

1. Download the sample_import_data.json file from the link above
2. Launch the CiteTrack app
3. Open Settings → Data Management section
4. Click "Import from File" or "Import Citation Data"
5. Select the downloaded sample_import_data.json file
6. The app will:
   - Import the scholar (kukA0LcAAAAJ) into the app
   - Import 6 citation history records
   - Display a success message showing imported data
7. After import:
   - The scholar will appear in the main list
   - Click on the scholar to view the citation history chart
   - The chart will show the tracking trend from 1400 to 1500 citations over time (Nov 20-25, 2025)

**File Format:**
The JSON file contains:
- "scholars": Array with scholar information (ID, name, citation count)
- "citationHistory": Array with 6 historical citation data points
- Each history entry includes: scholarId, citationCount, and timestamp

**Tracking Feature:**
The app tracks citations by:
1. Fetching current citation count from Google Scholar (https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en)
2. Automatically saving citation data to history when it changes
3. Displaying historical trends in charts
4. Allowing export/import of tracking data

The import feature allows users to restore exported data or sync data between devices.

The sample file will remain available at the provided link for future reviews.

Thank you for your attention.
```

## 回复模板（中文）

```
感谢您的审核。

我已经准备了一个示例 JSON 文件用于测试导入功能。文件托管在公开可访问的位置，将持续可用以供未来审核。

**示例导入文件：**
[在这里插入文件的直接下载链接]

**文件详情：**
- 文件名：sample_import_data.json
- 格式：JSON
- 内容：演示学者 ID（kukA0LcAAAAJ）及引用跟踪数据
- 6 条引用历史数据点，显示从 1400 到 1500 次引用的跟踪

**如何测试导入功能：**

1. 从上面的链接下载 sample_import_data.json 文件
2. 启动 CiteTrack 应用
3. 打开设置 → 数据管理部分
4. 点击"从文件导入"或"导入引用数据"
5. 选择下载的 sample_import_data.json 文件
6. 应用将：
   - 导入学者（kukA0LcAAAAJ）到应用中
   - 导入 6 条引用历史记录
   - 显示成功消息，显示导入的数据
7. 导入后：
   - 学者将出现在主列表中
   - 点击学者查看引用历史图表
   - 图表将显示从 1400 到 1500 次引用的跟踪趋势（2025年11月20-25日）

**文件格式：**
JSON 文件包含：
- "scholars"：学者信息数组（ID、姓名、引用数）
- "citationHistory"：6 条历史引用数据点数组
- 每个历史条目包括：scholarId、citationCount 和 timestamp

**跟踪功能：**
应用通过以下方式跟踪引用：
1. 从 Google Scholar 获取当前引用数（https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en）
2. 当引用数发生变化时自动保存到历史记录
3. 在图表中显示历史趋势
4. 允许导出/导入跟踪数据

导入功能允许用户恢复导出的数据或在设备之间同步数据。

示例文件将在提供的链接处持续可用，以供未来审核。

感谢您的关注。
```

## 快速操作指南

### 使用 GitHub Gist（最简单）

1. 访问：https://gist.github.com/
2. 点击 "New gist"
3. 文件名：`sample_import_data.json`
4. 粘贴文件内容（从 `macOS/sample_import_data.json`）
5. 选择 "Create public gist"
6. 创建后，点击 "Raw" 获取链接
7. 在 App Store Connect 回复中使用这个链接

### 文件内容（如果需要手动创建）

文件内容在：`/Users/tao.shen/google_scholar_plugin/macOS/sample_import_data.json`

## 重要提示

1. ✅ **文件必须公开**：确保文件可以公开访问，无需登录
2. ✅ **直接下载链接**：提供 Raw 链接或直接下载链接
3. ✅ **持续可用**：选择稳定的托管服务（GitHub 推荐）
4. ✅ **文件格式**：确保是 .json 格式
5. ✅ **测试链接**：在上传后，自己测试一下链接是否可以下载

## 验证清单

在发送回复前：
- [ ] 文件已上传到可访问的位置
- [ ] 链接可以正常下载文件
- [ ] 文件格式是 .json
- [ ] 文件内容是有效的 JSON
- [ ] 链接是公开的，无需登录
- [ ] 在回复中提供了链接和详细说明

