# 回复 Apple 审核的说明

## 关于 Entitlements 的回复

如果 Apple 审核团队询问关于 `com.apple.security.files.downloads.read-write` 权限的问题，可以使用以下回复：

---

**英文版本**：

```
Thank you for your review. 

Regarding the entitlement "com.apple.security.files.downloads.read-write":

We have removed this entitlement from our app as it is not needed. Our app does not directly access the Downloads folder. 

The app's export functionality uses NSSavePanel, which only requires "com.apple.security.files.user-selected.read-write" entitlement. Users can choose any location to save exported files, not just the Downloads folder.

We have updated the binary with the corrected entitlements file that removes the unnecessary "downloads.read-write" permission.

Thank you for your attention to this matter.
```

**中文版本**：

```
感谢您的审核。

关于权限 "com.apple.security.files.downloads.read-write"：

我们已经从应用中移除了此权限，因为应用不需要它。我们的应用不会直接访问下载文件夹。

应用的导出功能使用 NSSavePanel，只需要 "com.apple.security.files.user-selected.read-write" 权限。用户可以选择任何位置保存导出的文件，不仅仅是下载文件夹。

我们已经更新了二进制文件，修正了 entitlements 文件，移除了不必要的 "downloads.read-write" 权限。

感谢您的关注。
```

---

## 关于演示账户的回复

如果 Apple 审核团队询问演示账户问题，可以使用以下回复：

---

**英文版本**：

```
Thank you for your review.

CiteTrack does not require user login or account creation. The app uses publicly available Google Scholar data and only requires a Google Scholar ID (a public scholar identifier) to function.

To test the app:
1. Launch the app
2. Click "Add Scholar" or the "+" button
3. Enter a Google Scholar ID (e.g., "kukA0LcAAAAJ" or any other public Google Scholar profile ID)
4. Click "Add"
5. The app will automatically fetch and display citation data for that scholar

All features can be tested by entering a Google Scholar ID - no account or login is required.

We have provided this information in the App Review Information section of App Store Connect.

Thank you for your understanding.
```

**中文版本**：

```
感谢您的审核。

CiteTrack 不需要用户登录或创建账户。应用使用 Google Scholar 的公开数据，只需要 Google Scholar ID（公开的学者标识符）即可使用。

测试步骤：
1. 启动应用
2. 点击"添加学者"或"+"按钮
3. 输入 Google Scholar ID（例如："kukA0LcAAAAJ" 或任何其他公开的 Google Scholar 个人资料 ID）
4. 点击"添加"
5. 应用会自动获取并显示该学者的引用数据

所有功能都可以通过输入 Google Scholar ID 来测试，无需任何账户或登录。

我们已经在 App Store Connect 的 App 审核信息部分提供了这些信息。

感谢您的理解。
```

---

## 如何在 App Store Connect 中回复

1. 登录 [App Store Connect](https://appstoreconnect.apple.com/)
2. 进入你的应用
3. 找到被拒绝的版本
4. 点击 **"回复 App 审核"** (Reply to App Review) 按钮
5. 粘贴上面的相应回复
6. 点击 **"发送"** (Send)

## 重要提示

- 回复要礼貌、专业
- 说明要清晰、具体
- 如果已经修复了问题，要明确说明
- 如果提供了新信息，要确保在 App Store Connect 中也更新了相应字段

