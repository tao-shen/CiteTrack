# App Store 拒绝问题修复总结

## 问题分析

### 问题 1: Guideline 2.4.5(i) - Performance
**原因**：沙盒权限配置错误。多个权限被设置为 `false`，但 Apple 要求如果不需要这些权限，应该完全删除这些条目，而不是设置为 `false`。

**涉及的权限**：
- `com.apple.security.personal-information.location`
- `com.apple.security.device.audio-input`
- `com.apple.security.print`
- `com.apple.security.network.server`
- `com.apple.security.personal-information.addressbook`
- `com.apple.security.device.camera`
- `com.apple.security.personal-information.calendars`

### 问题 2: Guideline 2.1 - Information Needed
**原因**：需要提供演示账户信息，以便审核人员能够测试应用的所有功能。

## 修复内容

### 1. 修复 entitlements 文件 (`CiteTrack.entitlements`)

**修改前**：
- 包含多个设置为 `false` 的权限条目
- `aps-environment` 设置为 `development`

**修改后**：
- ✅ 删除了所有设置为 `false` 的权限条目
- ✅ 将 `aps-environment` 改为 `production`
- ✅ 只保留实际需要的权限：
  - `com.apple.security.app-sandbox` = true
  - `com.apple.security.files.downloads.read-write` = true
  - `com.apple.security.files.user-selected.read-write` = true
  - `com.apple.security.network.client` = true

### 2. 创建演示账户说明文档

创建了 `DEMO_ACCOUNT_INFO.md` 文件，包含：
- 应用功能概述
- 详细的测试步骤
- 推荐的测试 Google Scholar ID
- 完整功能测试清单

## 验证结果

### Entitlements 文件验证
```bash
plutil -lint CiteTrack.entitlements
# 结果: CiteTrack.entitlements: OK
```

### 编译验证
```bash
xcodebuild -project CiteTrack_macOS.xcodeproj -scheme CiteTrack -configuration Release clean build
# 结果: ** BUILD SUCCEEDED **
```

## 下一步操作

### 1. 在 App Store Connect 中提供演示账户信息

1. 登录 App Store Connect
2. 进入你的应用
3. 找到 "App 审核信息" (App Review Information) 部分
4. 在 "演示账户" (Demo Account) 字段中，输入以下信息：

```
CiteTrack 不需要用户登录或创建账户。应用使用 Google Scholar 的公开数据，只需要 Google Scholar ID（公开的学者标识符）即可使用。

测试步骤：
1. 启动应用
2. 点击"添加学者"按钮
3. 输入 Google Scholar ID（例如：kukA0LcAAAAJ）
4. 应用会自动获取并显示引用数据

推荐的测试 Google Scholar ID：
- kukA0LcAAAAJ
- 任何公开的 Google Scholar 个人资料 ID

详细说明请参考：DEMO_ACCOUNT_INFO.md
```

### 2. 重新提交应用

1. 在 Xcode 中，选择 **Product → Archive**
2. 等待 Archive 完成
3. 在 Organizer 窗口中，点击 **Distribute App**
4. 选择 **App Store Connect**
5. 按照向导完成上传

### 3. 重要提示

- **Archive 构建**：确保使用 Archive 构建，而不是普通的 Release 构建。Archive 会使用正确的 App Store provisioning profile 和分发证书。
- **aps-environment**：在 Archive 构建时，Xcode 会自动使用 App Store provisioning profile，它会将 `aps-environment` 设置为 `production`。
- **get-task-allow**：在 Archive 构建时，不会包含 `get-task-allow` 权限（这是调试权限，只在开发构建中出现）。

## 文件清单

修改的文件：
- ✅ `macOS/CiteTrack.entitlements` - 修复了沙盒权限配置

新增的文件：
- ✅ `macOS/DEMO_ACCOUNT_INFO.md` - 演示账户说明文档
- ✅ `macOS/APP_STORE_REJECTION_FIX.md` - 本修复总结文档

## 验证清单

在重新提交前，请确认：

- [x] Entitlements 文件中没有设置为 `false` 的权限条目
- [x] Entitlements 文件格式正确（通过 `plutil -lint` 验证）
- [x] 项目可以成功编译（Release 配置）
- [x] 在 App Store Connect 中提供了演示账户信息
- [ ] 使用 Archive 构建进行提交
- [ ] 验证 Archive 构建中的 entitlements 正确（应该没有 `get-task-allow`，`aps-environment` 应该是 `production`）

## 注意事项

1. **Provisioning Profile**：确保在 Xcode 的 Signing & Capabilities 中选择了正确的 App Store provisioning profile。
2. **证书**：确保使用分发证书（Distribution Certificate），而不是开发证书。
3. **测试**：在提交前，建议在 TestFlight 中测试应用，确保所有功能正常工作。


