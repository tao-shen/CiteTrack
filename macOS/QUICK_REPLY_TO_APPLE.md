# 快速回复 Apple 审核（可直接复制）

## 重要更新：关于导入功能

Apple 审核团队需要测试**导入功能**。请确保：
1. 在回复中附加 `sample_import_data.json` 文件
2. 或者提供文件的下载链接
3. 详细说明如何测试导入功能

## 英文版本（推荐 - 包含导入功能说明）

直接复制以下内容到 App Store Connect 的回复框中：

---

Thank you for your review.

I understand you need to test the **import feature**. I've prepared a sample import file for you.

**Sample Import File:**
I've attached a sample JSON file (sample_import_data.json) containing demo scholar ID (kukA0LcAAAAJ) with sample citation tracking data.

**To Test the Import Feature:**
1. Launch the app
2. Open Settings → Data Management section
3. Click "Import from File" or "Import Citation Data"
4. Select the sample_import_data.json file
5. The app will import the scholar and citation history
6. View the imported data: Click on the scholar to see the citation history chart showing tracking from 1400 to 1500 citations over time

**Sample File Contents:**
- Scholar ID: kukA0LcAAAAJ
- 6 citation history data points (Nov 20-25, 2025)
- Shows tracking trend from 1400 to 1500 citations

**Tracking Feature:**
CiteTrack tracks citation data from publicly available Google Scholar profiles:

**Demo Scholar ID**: kukA0LcAAAAJ
**Direct link**: https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en

**How the tracking feature works:**

1. The app accesses publicly available Google Scholar profile pages at:
   https://scholar.google.com/citations?user={SCHOLAR_ID}&hl=en

2. **To test the tracking feature:**
   a. Launch the app
   b. Click "Add Scholar" or the "+" button
   c. Enter the Google Scholar ID: kukA0LcAAAAJ
   d. Click "Add"
   e. The app will automatically:
      - Fetch the scholar's name and current citation count from Google Scholar
      - Display the data in the main interface
      - Save the citation count to history (if it has changed)
   f. To view tracking history:
      - Click on the scholar in the list
      - View the citation history chart showing trends over time
      - Export data in JSON or CSV format

3. **Tracking features:**
   - Fetches total citation count from the scholar's profile page
   - Tracks citation history over time (automatically saves data when citation count changes)
   - Displays citation trends in interactive charts
   - Sends notifications when citation count changes
   - Allows data export in multiple formats

The app fetches data in real-time from Google Scholar (https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en) and automatically saves citation changes to history. The import feature allows users to restore exported data or sync data between devices.

**File Attachment:**
The sample_import_data.json file is attached to this message for your testing.

Thank you for your attention.

---

## 中文版本

直接复制以下内容到 App Store Connect 的回复框中：

---

感谢您的审核。

我理解您需要测试**导入功能**。我已经为您准备了一个示例导入文件。

**示例导入文件：**
我已经附加了一个示例 JSON 文件（sample_import_data.json），其中包含演示学者 ID（kukA0LcAAAAJ）和示例引用跟踪数据。

**测试导入功能：**
1. 启动应用
2. 打开设置 → 数据管理部分
3. 点击"从文件导入"或"导入引用数据"
4. 选择 sample_import_data.json 文件
5. 应用将导入学者和引用历史
6. 查看导入的数据：点击学者查看引用历史图表，显示从 1400 到 1500 次引用的跟踪趋势

**示例文件内容：**
- 学者 ID：kukA0LcAAAAJ
- 6 条引用历史数据点（2025年11月20-25日）
- 显示从 1400 到 1500 次引用的跟踪趋势

**跟踪功能：**
CiteTrack 从公开可访问的 Google Scholar 个人资料页面跟踪引用数据：

**演示学者 ID**：kukA0LcAAAAJ
**直接链接**：https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en

**跟踪功能的工作原理：**

1. 应用访问公开可访问的 Google Scholar 个人资料页面：
   https://scholar.google.com/citations?user={学者ID}&hl=en

2. **测试跟踪功能：**
   a. 启动应用
   b. 点击"添加学者"或"+"按钮
   c. 输入 Google Scholar ID：kukA0LcAAAAJ
   d. 点击"添加"
   e. 应用将自动：
      - 从 Google Scholar 获取学者的姓名和当前引用数
      - 在主界面显示数据
      - 将引用数保存到历史记录（如果发生变化）
   f. 查看跟踪历史：
      - 点击列表中的学者
      - 查看显示随时间变化的引用历史图表
      - 以 JSON 或 CSV 格式导出数据

3. **跟踪功能：**
   - 从学者的个人资料页面获取总引用数
   - 跟踪引用历史（当引用数发生变化时自动保存数据）
   - 在交互式图表中显示引用趋势
   - 当引用数发生变化时发送通知
   - 支持多种格式的数据导出

应用从 Google Scholar（https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en）实时获取数据，并在引用数发生变化时自动保存到历史记录。导入功能允许用户恢复导出的数据或在设备之间同步数据。

**文件附件：**
示例文件 sample_import_data.json 已附加在此消息中供您测试。

感谢您的关注。

---

## 使用说明

1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)
2. 进入 CiteTrack 应用
3. 找到被拒绝的版本（版本 1.0.0）
4. 点击 **"回复 App 审核"** (Reply to App Review) 按钮
5. **推荐使用英文版本**（更专业，审核人员更容易理解）
6. 复制粘贴上面的相应回复
7. **重要：附加示例文件**
   - 点击"附加文件"或"Attach File"按钮
   - 选择 `macOS/sample_import_data.json` 文件
   - 或者提供文件的下载链接
8. 点击 **"发送"** (Send)

## 如果无法附加文件

如果 App Store Connect 不允许附加文件，可以：
1. 将 `sample_import_data.json` 上传到 GitHub Gist 或你的网站
2. 在回复中提供直接下载链接
3. 或者在回复中直接粘贴 JSON 内容，说明审核人员可以复制保存为文件

## 重要提示

- ✅ 回复要及时（建议在收到拒绝通知后 24 小时内回复）
- ✅ 使用英文版本更专业
- ✅ 确保包含演示学者 ID 和直接链接
- ✅ 提供详细的测试步骤

