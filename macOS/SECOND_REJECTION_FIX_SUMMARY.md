# 第二次拒绝问题修复总结

## 被拒绝的原因

### 问题 1: Guideline 2.1 - Information Needed
**原因**：仍然无法访问应用的所有功能，需要演示账户信息。

### 问题 2: Guideline 2.4.5(i) - Performance
**原因**：应用使用了 `com.apple.security.files.downloads.read-write` 权限，但审核人员没有看到应用中有使用这个权限的功能。

## 修复内容

### 1. 删除不必要的 downloads 权限 ✅

**修改前**：
```xml
<key>com.apple.security.files.downloads.read-write</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

**修改后**：
```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

**原因说明**：
- 应用使用 `NSSavePanel` 进行文件导出，只需要 `user-selected.read-write` 权限
- 应用不会直接访问 Downloads 文件夹
- App Store 版本不使用 Sparkle 框架（有 `#if !APP_STORE` 条件编译），因此不需要 downloads 权限

### 2. 创建详细的演示账户填写指南 ✅

创建了 `APP_STORE_CONNECT_DEMO_ACCOUNT_GUIDE.md`，包含：
- 详细的 App Store Connect 操作步骤
- 完整的演示账户信息文本（可直接复制粘贴）
- 测试步骤说明

### 3. 创建审核回复模板 ✅

创建了 `APPLE_REVIEW_RESPONSE.md`，包含：
- 关于删除 downloads 权限的说明（中英文）
- 关于演示账户的说明（中英文）
- 如何在 App Store Connect 中回复审核

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

### 最终 Entitlements 内容
- ✅ `com.apple.security.app-sandbox` = true
- ✅ `com.apple.security.files.user-selected.read-write` = true
- ✅ `com.apple.security.network.client` = true
- ❌ `com.apple.security.files.downloads.read-write` = **已删除**

## 下一步操作

### 1. 在 App Store Connect 中填写演示账户信息

**重要**：必须按照 `APP_STORE_CONNECT_DEMO_ACCOUNT_GUIDE.md` 中的步骤操作。

1. 登录 App Store Connect
2. 进入 CiteTrack 应用
3. 找到 "App 审核信息" → "演示账户"
4. **直接复制粘贴**指南中提供的完整文本

### 2. 重新提交应用

1. 在 Xcode 中，选择 **Product → Archive**
2. 等待 Archive 完成
3. 在 Organizer 窗口中，点击 **Distribute App**
4. 选择 **App Store Connect**
5. 按照向导完成上传

### 3. 如果需要回复 Apple 审核

如果 Apple 审核团队询问关于权限的问题，可以参考 `APPLE_REVIEW_RESPONSE.md` 中的模板进行回复。

## 文件清单

修改的文件：
- ✅ `macOS/CiteTrack.entitlements` - 删除了 `downloads.read-write` 权限

新增的文件：
- ✅ `macOS/APP_STORE_CONNECT_DEMO_ACCOUNT_GUIDE.md` - 详细的演示账户填写指南
- ✅ `macOS/APPLE_REVIEW_RESPONSE.md` - 审核回复模板
- ✅ `macOS/SECOND_REJECTION_FIX_SUMMARY.md` - 本修复总结文档

## 重要提示

1. **演示账户信息**：必须在 App Store Connect 中正确填写，这是导致第二次拒绝的主要原因之一。

2. **权限最小化**：Apple 要求应用只使用必要的权限。删除 `downloads.read-write` 权限是正确的，因为应用不需要它。

3. **Archive 构建**：确保使用 Archive 构建进行提交，而不是普通的 Release 构建。

4. **验证**：在提交前，建议验证：
   - [x] Entitlements 文件中没有 `downloads.read-write` 权限
   - [x] 项目可以成功编译
   - [ ] 在 App Store Connect 中填写了演示账户信息
   - [ ] 使用 Archive 构建进行提交

## 常见问题

**Q: 为什么删除了 downloads 权限？**
A: 应用使用 `NSSavePanel` 进行文件导出，只需要 `user-selected.read-write` 权限。应用不会直接访问 Downloads 文件夹。

**Q: 如果 Apple 询问为什么删除权限怎么办？**
A: 参考 `APPLE_REVIEW_RESPONSE.md` 中的回复模板，说明应用不需要该权限，导出功能使用 `NSSavePanel`。

**Q: 演示账户信息在哪里填写？**
A: 在 App Store Connect 的 "App 审核信息" → "演示账户" 字段中填写。详细步骤见 `APP_STORE_CONNECT_DEMO_ACCOUNT_GUIDE.md`。

