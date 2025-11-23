# 修复 App Store 提交问题

本文档说明如何修复 App Store 提交时遇到的两个问题：

1. **App Sandbox 未启用**：Sparkle 框架组件需要 App Sandbox entitlements
2. **缺少 dSYM 文件**：需要确保生成所有组件的调试符号文件

## 问题 1：App Sandbox 未启用

### 解决方案

Sparkle 框架内的可执行文件需要单独的 entitlements 文件。我们已经创建了 `Sparkle.entitlements` 文件，现在需要在 Xcode 中添加构建脚本来为这些组件签名。

### 步骤

1. **打开 Xcode 项目**
   ```bash
   open /Users/tao.shen/google_scholar_plugin/macOS/CiteTrack_macOS.xcodeproj
   ```

2. **添加构建脚本阶段**
   - 选择项目文件（蓝色图标）
   - 选择 **CiteTrack** target
   - 点击 **Build Phases** 标签
   - 点击左上角的 **+** 按钮
   - 选择 **New Run Script Phase**
   - 将新阶段拖到 **Embed Frameworks** 阶段之后

3. **配置脚本**
   - 展开新的 **Run Script** 阶段
   - 在 **Shell** 框中输入：
     ```bash
     /bin/bash
     ```
   - 在脚本框中输入：
     ```bash
     "${SRCROOT}/scripts/sign_sparkle_components.sh"
     ```
   - 取消勾选 **"Show environment variables in build log"**（可选）
   - 确保 **"Based on dependency analysis"** 已勾选

4. **验证**
   - 构建项目（⌘B）
   - 检查构建日志，应该看到 "✅ Signed ..." 消息

## 问题 2：缺少 dSYM 文件

### 解决方案

确保所有组件都生成 dSYM 文件。

### 步骤

1. **检查 Build Settings**
   - 选择项目 → **CiteTrack** target → **Build Settings**
   - 搜索 `DEBUG_INFORMATION_FORMAT`
   - 确保 **Debug** 和 **Release** 配置都设置为：
     ```
     DWARF with dSYM File
     ```

2. **检查其他设置**
   - 搜索 `GENERATE_DEBUG_SYMBOLS`
   - 确保设置为 `YES`
   - 搜索 `STRIP_INSTALLED_PRODUCT`
   - 对于 Release 配置，可以设置为 `YES`（但会移除符号，建议保持 `NO` 用于调试）

3. **Archive 构建**
   - 选择 **Product → Archive**
   - 等待构建完成
   - 在 Organizer 中检查 archive，应该包含 `.dSYM` 文件

## 验证修复

### 检查 App Sandbox

1. 构建并 Archive 项目
2. 在 Organizer 中选择 archive
3. 点击 **Distribute App**
4. 选择 **App Store Connect**
5. 如果不再出现 App Sandbox 错误，说明修复成功

### 检查 dSYM

1. 在 Organizer 中选择 archive
2. 右键点击 archive → **Show in Finder**
3. 右键点击 `.xcarchive` 文件 → **Show Package Contents**
4. 导航到 `dSYMs` 文件夹
5. 应该包含以下文件：
   - `CiteTrack.app.dSYM`
   - `Sparkle.framework.dSYM`（如果存在）
   - 其他相关组件的 dSYM

## 注意事项

1. **Sparkle 框架**：如果您的应用要提交到 App Store，通常不应该包含 Sparkle，因为 App Store 有自己的更新机制。但如果您确实需要 Sparkle（例如用于非 App Store 分发），则需要按照上述步骤处理。

2. **代码签名**：确保您有有效的开发者证书和配置文件。

3. **Entitlements**：`Sparkle.entitlements` 文件已经创建，包含必要的 App Sandbox 权限。

## 替代方案：移除 Sparkle（仅用于 App Store）

如果您只打算通过 App Store 分发，可以完全移除 Sparkle：

1. 在 Xcode 中，从 **Frameworks, Libraries, and Embedded Content** 中移除 Sparkle
2. 从代码中移除所有 Sparkle 相关的导入和使用
3. 使用条件编译：
   ```swift
   #if !APP_STORE
   import Sparkle
   #endif
   ```

