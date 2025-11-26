# Apple 审核回复 - 示例文件和跟踪功能说明

## 回复模板（英文）

```
Thank you for your review.

CiteTrack tracks citation data from publicly available Google Scholar profiles. The app does not require sample files to be hosted separately, as it directly accesses Google Scholar's public website.

Here's how the tracking feature works:

1. **Data Source**: The app accesses publicly available Google Scholar profile pages at:
   https://scholar.google.com/citations?user={SCHOLAR_ID}&hl=en

2. **Demo Scholar ID**: kukA0LcAAAAJ
   - Direct link: https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en
   - This is a publicly accessible Google Scholar profile page

3. **Tracking Features**:
   - Fetches total citation count from the scholar's profile page
   - Tracks citation history over time (saves data when citation count changes)
   - Displays citation trends in charts
   - Sends notifications when citation count changes

4. **How to Test**:
   a. Launch the app
   b. Click "Add Scholar" or the "+" button
   c. Enter the Google Scholar ID: kukA0LcAAAAJ
   d. Click "Add"
   e. The app will automatically:
      - Fetch the scholar's name and current citation count
      - Display the data in the main interface
      - Save the citation count to history (if it has changed)
   f. To view tracking history:
      - Click on the scholar in the list
      - View the citation history chart
      - Export data (JSON/CSV format)

5. **Sample Data**:
   The app tracks the following data points:
   - Scholar name (e.g., extracted from the profile page)
   - Total citations (e.g., displayed on the profile page)
   - Timestamp of each data point
   - Citation changes over time

All data is fetched in real-time from Google Scholar's public website. No separate hosting is required as the data source (Google Scholar) is publicly accessible and stable.

The tracking feature automatically saves citation data to the app's local database whenever the citation count changes, allowing users to view historical trends and export their tracking data.

Thank you for your attention.
```

## 回复模板（中文）

```
感谢您的审核。

CiteTrack 从公开可访问的 Google Scholar 个人资料页面跟踪引用数据。应用不需要单独托管的示例文件，因为它直接访问 Google Scholar 的公开网站。

跟踪功能的工作原理：

1. **数据来源**：应用访问公开可访问的 Google Scholar 个人资料页面：
   https://scholar.google.com/citations?user={学者ID}&hl=en

2. **演示学者 ID**：kukA0LcAAAAJ
   - 直接链接：https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en
   - 这是一个公开可访问的 Google Scholar 个人资料页面

3. **跟踪功能**：
   - 从学者的个人资料页面获取总引用数
   - 跟踪引用历史（当引用数发生变化时保存数据）
   - 在图表中显示引用趋势
   - 当引用数发生变化时发送通知

4. **测试步骤**：
   a. 启动应用
   b. 点击"添加学者"或"+"按钮
   c. 输入 Google Scholar ID：kukA0LcAAAAJ
   d. 点击"添加"
   e. 应用将自动：
      - 获取学者的姓名和当前引用数
      - 在主界面显示数据
      - 将引用数保存到历史记录（如果发生变化）
   f. 查看跟踪历史：
      - 点击列表中的学者
      - 查看引用历史图表
      - 导出数据（JSON/CSV 格式）

5. **示例数据**：
   应用跟踪以下数据点：
   - 学者姓名（从个人资料页面提取）
   - 总引用数（在个人资料页面上显示）
   - 每个数据点的时间戳
   - 引用数随时间的变化

所有数据都是从 Google Scholar 的公开网站实时获取的。由于数据源（Google Scholar）是公开可访问且稳定的，因此不需要单独托管。

跟踪功能会在引用数发生变化时自动将引用数据保存到应用的本地数据库，允许用户查看历史趋势并导出跟踪数据。

感谢您的关注。
```

## 额外的示例 Google Scholar ID（可选）

如果审核人员需要更多示例，可以提供以下公开的 Google Scholar ID：

1. **kukA0LcAAAAJ** - 主要演示 ID
   - URL: https://scholar.google.com/citations?user=kukA0LcAAAAJ&hl=en

2. **其他公开的 Google Scholar ID**（如果第一个不可用）：
   - 任何公开的 Google Scholar 个人资料 ID 都可以使用
   - 用户可以在 Google Scholar 上搜索任何学者，找到他们的个人资料 ID

## 重要说明

1. **数据来源是公开的**：Google Scholar 个人资料页面是公开可访问的，不需要登录或特殊权限。

2. **实时数据**：应用从 Google Scholar 实时获取数据，不需要预先准备的示例文件。

3. **跟踪机制**：
   - 应用定期检查引用数（根据用户设置的更新间隔）
   - 当引用数发生变化时，自动保存到历史记录
   - 用户可以查看历史趋势图表
   - 用户可以导出跟踪数据

4. **数据格式**：
   - 应用解析 Google Scholar 页面的 HTML 来提取引用数据
   - 数据保存在本地 Core Data 数据库中
   - 可以导出为 JSON 或 CSV 格式

## 如何在 App Store Connect 中回复

1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)
2. 进入 CiteTrack 应用
3. 找到被拒绝的版本
4. 点击 **"回复 App 审核"** (Reply to App Review) 按钮
5. 选择使用英文或中文版本（建议使用英文）
6. 粘贴上面的相应回复
7. 点击 **"发送"** (Send)

## 如果审核人员仍然要求示例文件

如果审核人员坚持要求提供示例文件，可以：

1. **创建一个简单的 HTML 示例文件**，模拟 Google Scholar 页面的结构
2. **说明**：由于 Google Scholar 是第三方服务，我们无法控制其页面结构。应用直接从 Google Scholar 获取数据。
3. **提供截图**：可以截图显示应用如何显示跟踪数据

但最好的方法是强调应用直接访问公开的 Google Scholar 网站，这是应用的核心功能。


