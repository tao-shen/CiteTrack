# 如何托管示例文件供 Apple 审核

## 最简单的方法：GitHub Gist

### 步骤 1：准备文件

文件位置：`/Users/tao.shen/google_scholar_plugin/macOS/sample_import_data.json`

### 步骤 2：创建 GitHub Gist

1. **访问 GitHub Gist**
   ```
   https://gist.github.com/
   ```

2. **如果没有 GitHub 账户**
   - 点击 "Sign up" 注册
   - 或使用现有账户登录

3. **创建新的 Gist**
   - 点击右上角的 "+" 或 "New gist" 按钮
   - 在 "Filename including extension" 中输入：`sample_import_data.json`
   - 在编辑器中，打开 `sample_import_data.json` 文件，复制全部内容并粘贴
   - **重要**：选择 "Create public gist"（不要选择 "Create secret gist"）
   - 点击 "Create public gist" 按钮

4. **获取 Raw 链接**
   - 创建成功后，你会看到 Gist 页面
   - 点击文件名 `sample_import_data.json` 旁边的 "Raw" 按钮
   - 浏览器会打开 Raw 文件页面
   - **复制浏览器地址栏中的完整 URL**
   - URL 格式类似：`https://gist.githubusercontent.com/你的用户名/gist_id/raw/.../sample_import_data.json`

### 步骤 3：在 App Store Connect 中使用

1. 登录 App Store Connect
2. 进入 CiteTrack 应用
3. 找到被拒绝的版本
4. 点击 "回复 App 审核"
5. 使用以下回复模板（替换链接）：

```
Thank you for your review.

I've prepared a sample JSON file for testing the import feature. The file is hosted at a publicly accessible location and will remain available for future reviews.

**Sample Import File (Direct Download Link):**
[在这里粘贴你从 GitHub Gist 复制的 Raw 链接]

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
6. The app will import the scholar and citation history
7. View the imported data: Click on the scholar to see the citation history chart showing tracking from 1400 to 1500 citations over time

**Tracking Feature:**
The app tracks citations by fetching data from Google Scholar (https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en) and automatically saving changes to history. The import feature allows restoring exported data or syncing between devices.

The sample file will remain available at the provided link for future reviews.

Thank you.
```

6. 点击 "发送"

## 验证链接

在发送回复前，请验证：
1. 点击链接，应该可以直接下载 JSON 文件
2. 下载的文件可以正常打开
3. 文件内容是有效的 JSON

## 如果 GitHub Gist 不可用

### 替代方案 1：GitHub Repository

1. 在 GitHub 上创建新的公开仓库
2. 上传 `sample_import_data.json` 文件
3. 在 GitHub 上打开文件，点击 "Raw" 获取链接

### 替代方案 2：你的网站

1. 将文件上传到你的网站
2. 确保可以公开访问
3. 提供直接下载链接

## 文件内容参考

如果需要手动创建，文件应包含：

```json
{
  "scholars": [
    {
      "id": "kukA0LcAAAAJ",
      "name": "Demo Scholar",
      "displayName": "Demo Scholar",
      "citations": 1500,
      "lastUpdated": "2025-11-25T10:00:00+00:00"
    }
  ],
  "citationHistory": [
    {
      "id": null,
      "scholarId": "kukA0LcAAAAJ",
      "scholarName": "Demo Scholar",
      "citationCount": 1400,
      "timestamp": "2025-11-20T10:00:00+00:00"
    },
    {
      "id": null,
      "scholarId": "kukA0LcAAAAJ",
      "scholarName": "Demo Scholar",
      "citationCount": 1420,
      "timestamp": "2025-11-21T10:00:00+00:00"
    },
    {
      "id": null,
      "scholarId": "kukA0LcAAAAJ",
      "scholarName": "Demo Scholar",
      "citationCount": 1440,
      "timestamp": "2025-11-22T10:00:00+00:00"
    },
    {
      "id": null,
      "scholarId": "kukA0LcAAAAJ",
      "scholarName": "Demo Scholar",
      "citationCount": 1460,
      "timestamp": "2025-11-23T10:00:00+00:00"
    },
    {
      "id": null,
      "scholarId": "kukA0LcAAAAJ",
      "scholarName": "Demo Scholar",
      "citationCount": 1480,
      "timestamp": "2025-11-24T10:00:00+00:00"
    },
    {
      "id": null,
      "scholarId": "kukA0LcAAAAJ",
      "scholarName": "Demo Scholar",
      "citationCount": 1500,
      "timestamp": "2025-11-25T10:00:00+00:00"
    }
  ],
  "exportDate": "2025-11-25T10:00:00+00:00",
  "version": "1.0.0"
}
```

## 重要提示

1. ✅ **必须使用 Raw 链接**：GitHub Gist 的 Raw 链接是直接下载链接
2. ✅ **文件必须公开**：确保 Gist 是公开的，不是私有的
3. ✅ **测试链接**：在发送前，自己测试一下链接是否可以下载
4. ✅ **持续可用**：GitHub Gist 是稳定的，文件会持续可用

