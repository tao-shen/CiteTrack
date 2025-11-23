# App Store 提交问题 - 最终修复指南

## 问题说明

您遇到的两个问题：
1. **App Sandbox 未启用**：Sparkle 框架组件缺少 App Sandbox entitlements
2. **缺少 dSYM 文件**：Sparkle 是第三方框架，没有源代码，无法生成 dSYM

## 解决方案

### 方案 A：修复 Sparkle 签名（推荐，如果必须保留 Sparkle）

#### 步骤 1：Archive 构建

1. 在 Xcode 中：**Product → Archive**
2. 等待 Archive 完成

#### 步骤 2：运行修复脚本

Archive 完成后，**立即**运行修复脚本（在提交到 App Store 之前）：

```bash
cd /Users/tao.shen/google_scholar_plugin/macOS

# 自动查找最新的 Archive 并修复
./scripts/fix_archive_entitlements.sh

# 或者手动指定 Archive 路径
./scripts/fix_archive_entitlements.sh ~/Library/Developer/Xcode/Archives/YYYY-MM-DD/CiteTrack*.xcarchive
```

脚本会：
- ✅ 自动检测签名身份
- ✅ 为所有 Sparkle 组件添加 App Sandbox entitlements
- ✅ 验证签名和 entitlements
- ✅ 重新签名整个应用包

#### 步骤 3：验证修复

```bash
# 检查 Autoupdate 的 entitlements
ARCHIVE_PATH="path/to/your.xcarchive"
codesign -d --entitlements - "$ARCHIVE_PATH/Products/Applications/CiteTrack.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" | grep -A 1 "app-sandbox"

# 应该看到：
# <key>com.apple.security.app-sandbox</key>
# <true/>
```

#### 步骤 4：提交到 App Store

在 Xcode Organizer 中：
1. 选择修复后的 Archive
2. **Distribute App**
3. **App Store Connect**
4. 完成上传

---

### 方案 B：移除 Sparkle（最简单，推荐用于 App Store）

如果您**只通过 App Store 分发**，最简单的方法是移除 Sparkle：

#### 步骤 1：在 Xcode 中移除 Sparkle

1. 打开项目
2. 选择项目 → **CiteTrack** target → **General**
3. 在 **Frameworks, Libraries, and Embedded Content** 中：
   - 找到 `Sparkle.framework`
   - 点击 **-** 移除它

#### 步骤 2：从代码中移除 Sparkle 引用

在 `main.swift` 或其他使用 Sparkle 的文件中，添加条件编译：

```swift
#if !APP_STORE
import Sparkle
// Sparkle 相关代码
#endif
```

#### 步骤 3：重新 Archive 和提交

这样就不会有任何 App Sandbox 或 dSYM 问题了。

---

## 关于 dSYM 问题

Sparkle 是第三方预编译框架，**没有源代码**，因此无法生成 dSYM 文件。

### 选项 1：从 Sparkle 官方获取 dSYM

1. 访问：https://github.com/sparkle-project/Sparkle/releases
2. 下载与您使用的版本对应的 dSYM 文件
3. 将 dSYM 文件复制到 Archive 的 `dSYMs` 文件夹中

### 选项 2：忽略警告

如果应用功能正常，这些 dSYM 警告**通常不会阻止提交**。App Store 可能会接受没有第三方框架 dSYM 的应用。

### 选项 3：移除 Sparkle

如果移除 Sparkle，就不会有 dSYM 问题了。

---

## 推荐工作流程

### 如果您必须保留 Sparkle：

1. **Archive 构建**
2. **运行修复脚本**：`./scripts/fix_archive_entitlements.sh`
3. **验证签名**（使用上面的命令）
4. **提交到 App Store**
5. **如果 dSYM 警告仍然出现**，可以忽略或从 Sparkle 官方获取 dSYM

### 如果您只通过 App Store 分发：

1. **移除 Sparkle 框架**
2. **移除 Sparkle 代码引用**
3. **重新 Archive**
4. **提交到 App Store**（不会有任何问题）

---

## 快速命令参考

```bash
# 修复 Archive 中的 Sparkle entitlements
cd /Users/tao.shen/google_scholar_plugin/macOS
./scripts/fix_archive_entitlements.sh

# 验证签名
codesign -d --entitlements - "path/to/archive/Products/Applications/CiteTrack.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" | grep app-sandbox

# 检查 Archive 中的 Sparkle
ls -la "path/to/archive/Products/Applications/CiteTrack.app/Contents/Frameworks/"
```

---

## 故障排除

### 如果修复脚本失败：

1. **检查 Archive 路径是否正确**
2. **确保有有效的签名身份**（在 Xcode 中配置）
3. **检查 entitlements 文件是否存在**：`macOS/Sparkle.entitlements`

### 如果仍然有 App Sandbox 错误：

1. **验证脚本是否成功执行**（查看脚本输出）
2. **手动验证签名**（使用上面的验证命令）
3. **考虑移除 Sparkle**（如果不需要）

---

## 总结

- ✅ **已创建修复脚本**：`scripts/fix_archive_entitlements.sh`
- ✅ **已创建 entitlements 文件**：`Sparkle.entitlements`
- ⚠️ **dSYM 问题**：Sparkle 是第三方框架，无法生成 dSYM（可以忽略或从官方获取）

**推荐**：如果只通过 App Store 分发，移除 Sparkle 是最简单的解决方案。

