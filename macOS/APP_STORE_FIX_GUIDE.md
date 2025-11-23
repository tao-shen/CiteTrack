# App Store 提交问题修复指南

## 问题 1：App Sandbox 未启用

### 当前状态
- ✅ 已创建 `Sparkle.entitlements` 文件
- ✅ 已添加构建脚本阶段来签名 Sparkle 组件
- ⚠️ 在 Debug 构建中签名可能失败（这是正常的）

### 重要说明

**在 Archive 构建时，签名脚本会自动使用正确的签名身份**。如果仍然遇到问题，请按以下步骤操作：

### 验证步骤

1. **Archive 构建**
   ```bash
   # 在 Xcode 中：Product → Archive
   ```

2. **验证签名**
   在 Archive 完成后，在 Terminal 中运行：
   ```bash
   # 找到 archive 路径（通常在 ~/Library/Developer/Xcode/Archives）
   ARCHIVE_PATH="path/to/your.xcarchive"
   
   # 检查 Autoupdate 的 entitlements
   codesign -d --entitlements - "$ARCHIVE_PATH/Products/Applications/CiteTrack.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
   
   # 应该看到 com.apple.security.app-sandbox = true
   ```

3. **如果签名仍然失败**

   可能需要在 Xcode 中手动配置：
   - 打开项目设置
   - 选择 **CiteTrack** target
   - 进入 **Build Phases**
   - 找到 **Sign Sparkle Components** 阶段
   - 确保它在 **Embed Frameworks** 之后
   - 确保 **"Based on dependency analysis"** 已取消勾选（这样每次构建都会运行）

### 替代方案：移除 Sparkle（推荐用于 App Store）

如果您只通过 App Store 分发，**强烈建议移除 Sparkle**：

1. 在 Xcode 中：
   - 选择项目 → **CiteTrack** target → **General**
   - 在 **Frameworks, Libraries, and Embedded Content** 中移除 Sparkle.framework

2. 从代码中移除 Sparkle 相关代码：
   ```swift
   #if !APP_STORE
   import Sparkle
   #endif
   ```

3. 这样就不会有 App Sandbox 问题了。

---

## 问题 2：缺少 dSYM 文件

### 原因
Sparkle 是第三方预编译框架，没有源代码，因此无法生成 dSYM 文件。

### 解决方案

#### 方案 1：从 Sparkle 官方获取 dSYM（推荐）

1. 访问 Sparkle 的 GitHub Releases：https://github.com/sparkle-project/Sparkle/releases
2. 下载与您使用的版本对应的 dSYM 文件
3. 将 dSYM 文件添加到 archive 的 `dSYMs` 文件夹中

#### 方案 2：创建占位符 dSYM（临时方案）

如果无法获取官方 dSYM，可以创建空的占位符：

```bash
# 在 Archive 后，手动添加占位符 dSYM
# 注意：这只是为了通过验证，实际调试时不会有符号信息
```

#### 方案 3：忽略警告（如果功能正常）

如果应用功能正常，这些 dSYM 警告通常不会阻止提交。App Store 可能会接受没有第三方框架 dSYM 的应用。

### 验证 dSYM

在 Archive 后检查：
```bash
ARCHIVE_PATH="path/to/your.xcarchive"
ls -la "$ARCHIVE_PATH/dSYMs/"
```

应该看到：
- `CiteTrack.app.dSYM` ✅
- `Sparkle.framework.dSYM`（如果添加了）✅

---

## 完整修复流程

### 步骤 1：Archive 构建

1. 在 Xcode 中：**Product → Archive**
2. 等待构建完成
3. 检查构建日志，确认看到 "✅ Signed ..." 消息

### 步骤 2：验证签名

```bash
# 在 Organizer 中右键 archive → Show in Finder
# 然后运行：
ARCHIVE_PATH="path/to/CiteTrack YYYY-MM-DD, HH.MM.xcarchive"

# 验证 Autoupdate
codesign -d --entitlements - "$ARCHIVE_PATH/Products/Applications/CiteTrack.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" | grep -A 1 "app-sandbox"

# 应该输出：<key>com.apple.security.app-sandbox</key><true/>
```

### 步骤 3：添加 dSYM（如果需要）

如果验证失败，从 Sparkle 官方下载 dSYM 并添加到 archive。

### 步骤 4：重新提交

在 Organizer 中：
1. 选择 archive
2. **Distribute App**
3. **App Store Connect**
4. 按照向导完成提交

---

## 如果问题仍然存在

### 检查清单

- [ ] Archive 构建是否成功？
- [ ] 构建日志中是否看到 "✅ Signed ..." 消息？
- [ ] `Sparkle.entitlements` 文件是否存在？
- [ ] 构建脚本阶段是否在 "Embed Frameworks" 之后？
- [ ] 是否使用了正确的签名身份（不是 ad-hoc）？

### 调试命令

```bash
# 检查 Sparkle 框架的签名
codesign -dvvv "path/to/CiteTrack.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"

# 检查 entitlements
codesign -d --entitlements - "path/to/CiteTrack.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"

# 验证签名
codesign --verify --verbose "path/to/CiteTrack.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
```

---

## 最终建议

**如果您只通过 App Store 分发，最简单的方法是移除 Sparkle**，因为：
1. App Store 有自己的自动更新机制
2. 不需要处理 Sparkle 的签名和 dSYM 问题
3. 应用包更小
4. 提交流程更简单

如果确实需要 Sparkle（例如用于非 App Store 分发），请按照上述步骤操作。

