# CiteTrack macOS App Store 提交完整指南

## 概述

本指南详细说明如何准备和提交CiteTrack macOS应用到App Store。主要解决了Sparkle自动更新框架与App Store的兼容性问题，以及dSYM符号文件的处理。

## 问题背景

提交macOS应用到App Store时，您可能遇到以下两个主要问题：

### 1. ❌ App Sandbox未启用错误

```
App sandbox not enabled. The following executables must include the 
"com.apple.security.app-sandbox" entitlement with a Boolean value of true:
- Sparkle.framework/Versions/B/Autoupdate
- Sparkle.framework/Versions/B/Updater.app
- Sparkle.framework/Versions/B/XPCServices/Downloader.xpc
- Sparkle.framework/Versions/B/XPCServices/Installer.xpc
```

**原因**：Sparkle是第三方自动更新框架，其内部组件没有App Store所需的沙盒权限。

**解决方案**：App Store应用不应使用Sparkle，因为App Store有自己的更新机制。

### 2. ❌ dSYM符号文件缺失错误

```
Upload Symbols Failed
The archive did not include a dSYM for the Sparkle components...
```

**原因**：Xcode Archive时没有正确生成或包含第三方框架的dSYM文件。

**解决方案**：配置Xcode正确生成dSYM文件，或移除不需要的框架。

---

## 解决方案

### 方案概述

我们使用**条件编译**的方法，为App Store构建创建一个不包含Sparkle的版本：

- **非App Store版本**：包含Sparkle，支持自动更新
- **App Store版本**：不包含Sparkle，通过App Store更新

---

## 第一步：在Xcode中配置App Store构建

### 1.1 打开Xcode项目

```bash
open /Users/tao.shen/google_scholar_plugin/macOS/CiteTrack_macOS.xcodeproj
```

### 1.2 创建App Store构建配置

1. 选择项目文件（最顶层的蓝色图标）
2. 在左侧选择 **CiteTrack** target
3. 点击 **Build Settings** 标签
4. 点击 **+** → **Add User-Defined Setting**
5. 创建新设置：
   - Name: `APP_STORE_BUILD`
   - Value: `YES`

### 1.3 配置编译标志

在 **Build Settings** 中：

1. 搜索 **"Swift Compiler - Custom Flags"**
2. 找到 **Other Swift Flags**
3. 展开 **Release** 配置
4. 点击 **+** 添加：
   ```
   -D APP_STORE
   ```

### 1.4 配置dSYM生成

在 **Build Settings** 中：

1. 搜索 **"Debug Information Format"**
   - Debug: `DWARF with dSYM File`
   - Release: `DWARF with dSYM File`

2. 搜索 **"Strip Debug Symbols During Copy"**
   - Release: `NO`

3. 搜索 **"Generate Debug Symbols"**
   - Debug: `YES`
   - Release: `YES`

### 1.5 配置Sparkle框架（可选链接）

在 **Build Settings** 中：

1. 搜索 **"Other Linker Flags"**
2. 为 **Release** 配置添加（如果Sparkle链接有问题）：
   ```
   -weak_framework Sparkle
   ```

或者，更好的方式是在 **Build Phases** → **Link Binary With Libraries** 中：
- 找到 `Sparkle.framework`
- 将其设置为 **Optional** 而不是 **Required**

---

## 第二步：清理并Archive

### 2.1 清理构建缓存

1. 在Xcode菜单中选择：**Product** → **Clean Build Folder**
2. 或使用快捷键：**Shift + Cmd + K**

### 2.2 删除DerivedData（可选但推荐）

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/CiteTrack-*
```

### 2.3 Archive应用

1. 确保选择的scheme是 **CiteTrack**
2. 确保选择的目标是 **Any Mac (Apple Silicon, Intel)**
3. 在Xcode菜单中选择：**Product** → **Archive**
4. 等待Archive完成（可能需要几分钟）

---

## 第三步：准备Archive上传

### 3.1 运行准备脚本

Archive完成后，运行我们提供的脚本：

```bash
cd /Users/tao.shen/google_scholar_plugin/macOS
./scripts/prepare_app_store.sh
```

脚本会自动：
- ✅ 查找最新的Archive
- ✅ 创建备份
- ✅ 移除Sparkle框架（如果存在）
- ✅ 验证沙盒权限
- ✅ 检查dSYM文件

如果需要手动指定Archive路径：

```bash
./scripts/prepare_app_store.sh ~/Library/Developer/Xcode/Archives/YYYY-MM-DD/CiteTrack*.xcarchive
```

### 3.2 验证Archive

在Xcode中：

1. 打开 **Window** → **Organizer**
2. 选择 **Archives** 标签
3. 找到刚才的Archive
4. 右键点击 → **Show in Finder**
5. 右键点击 Archive → **Show Package Contents**
6. 导航到：`Products/Applications/CiteTrack.app/Contents/Frameworks/`
7. **确认Sparkle.framework不存在**

---

## 第四步：上传到App Store Connect

### 4.1 使用Xcode Organizer上传

1. 在Organizer中选择Archive
2. 点击 **Distribute App**
3. 选择 **App Store Connect**
4. 点击 **Next**
5. 选择 **Upload**
6. 点击 **Next**
7. 保持默认选项：
   - ✅ Upload your app's symbols...
   - ✅ Manage Version and Build Number
8. 点击 **Next**
9. 选择签名证书（自动管理或手动选择）
10. 点击 **Upload**

### 4.2 验证上传

上传完成后（可能需要10-30分钟处理）：

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 选择 **My Apps** → **CiteTrack**
3. 在左侧选择 **TestFlight** 标签
4. 在 **iOS Builds** 或 **macOS Builds** 中查看
5. 等待状态从 **Processing** 变为 **Ready to Submit**

---

## 常见问题解决

### Q1: 仍然报告Sparkle沙盒错误

**解决方案A**：确认使用了APP_STORE编译标志

```bash
# 在Xcode Build Settings中验证：
# Other Swift Flags (Release) 包含 -D APP_STORE
```

**解决方案B**：手动从Archive中移除Sparkle

```bash
cd ~/Library/Developer/Xcode/Archives/YYYY-MM-DD/CiteTrack*.xcarchive/Products/Applications/CiteTrack.app/Contents/Frameworks
rm -rf Sparkle.framework
```

### Q2: dSYM文件仍然缺失

**解决方案**：

1. 打开Xcode项目
2. **Build Settings** → 搜索 **"Debug Information Format"**
3. 确保 **Release** 设置为 **DWARF with dSYM File**
4. 清理项目并重新Archive

### Q3: 代码签名错误

**解决方案**：

```bash
# 检查当前签名
codesign -dvv /path/to/CiteTrack.app

# 如果需要，重新签名
codesign --force --deep --sign "Developer ID Application: Your Name" /path/to/CiteTrack.app
```

### Q4: 上传后验证失败

检查App Store Connect中的详细错误信息：

1. App Store Connect → CiteTrack → Activity
2. 查看最新构建的详细信息
3. 根据具体错误消息调整

---

## 验证清单

在提交前，确保完成以下检查：

### 代码和配置

- [ ] ✅ Info.plist包含`LSApplicationCategoryType`
- [ ] ✅ 启用App Sandbox (`com.apple.security.app-sandbox = true`)
- [ ] ✅ 移除或禁用Sparkle框架
- [ ] ✅ 移除`SUEnableAutomaticChecks`配置
- [ ] ✅ Release构建使用`-D APP_STORE`标志
- [ ] ✅ Debug Information Format = DWARF with dSYM File

### Archive验证

- [ ] ✅ Archive中不包含Sparkle.framework
- [ ] ✅ Archive包含dSYM文件
- [ ] ✅ 应用正确签名
- [ ] ✅ 应用启用沙盒

### App Store Connect

- [ ] ✅ 应用图标（1024x1024，无透明度）
- [ ] ✅ 隐私政策链接
- [ ] ✅ 应用描述和关键词
- [ ] ✅ 截图（至少1个）
- [ ] ✅ 版本号和构建号正确

---

## 文件修改总结

### 修改的文件

1. **macOS/Sources/MainAppDelegate.swift**
   - 添加条件编译`#if !APP_STORE`
   - Sparkle相关代码仅在非App Store版本编译

2. **macOS/Info.plist**
   - 移除`SUEnableAutomaticChecks`键
   - 保持其他配置不变

3. **新建文件**
   - `macOS/scripts/prepare_app_store.sh` - Archive准备脚本
   - `macOS/APP_STORE_SUBMISSION_GUIDE.md` - 本指南

### 不需要修改的文件

- Sparkle.framework（保留用于非App Store构建）
- 其他源代码文件
- Entitlements文件（已正确配置）

---

## 构建两个版本

### App Store版本

```bash
# 在Xcode中
# 1. Scheme: CiteTrack
# 2. Configuration: Release
# 3. Other Swift Flags: -D APP_STORE
# 4. Product → Archive
```

### 直接分发版本（包含Sparkle）

```bash
# 在Xcode中
# 1. Scheme: CiteTrack
# 2. Configuration: Release
# 3. Other Swift Flags: (移除 -D APP_STORE)
# 4. Product → Archive
```

---

## 支持和帮助

### Apple资源

- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [App Sandbox文档](https://developer.apple.com/documentation/security/app_sandbox)
- [Distributing Custom Apps](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)

### 日志和调试

查看详细的上传日志：

```bash
# Xcode Organizer日志
~/Library/Logs/Xcode/

# 应用验证日志
xcrun altool --validate-app -f /path/to/CiteTrack.pkg -t osx --apiKey YOUR_KEY --apiIssuer YOUR_ISSUER
```

### 测试App Store构建

在上传前测试App Store版本：

```bash
# 构建并安装
xcodebuild -scheme CiteTrack -configuration Release -archivePath build/CiteTrack.xcarchive archive OTHER_SWIFT_FLAGS="-D APP_STORE"

# 验证Sparkle已禁用
# 运行应用，检查菜单中是否有"检查更新"选项（不应该有）
```

---

## 总结

通过使用条件编译和准备脚本，您现在可以：

1. ✅ 为App Store构建无Sparkle版本
2. ✅ 为直接分发构建包含Sparkle的版本
3. ✅ 避免App Store的沙盒和dSYM错误
4. ✅ 保持代码库统一，无需维护两个分支

**记住**：每次提交到App Store时，确保使用`-D APP_STORE`编译标志！

---

## 快速参考

### 一键准备和提交流程

```bash
# 1. 在Xcode中清理并Archive（确保使用APP_STORE标志）

# 2. 运行准备脚本
cd /Users/tao.shen/google_scholar_plugin/macOS
./scripts/prepare_app_store.sh

# 3. 在Xcode Organizer中上传

# 4. 完成！
```

### 关键命令

```bash
# 查找最新Archive
ls -lt ~/Library/Developer/Xcode/Archives/

# 检查应用签名
codesign -dvv ~/Library/Developer/Xcode/Archives/YYYY-MM-DD/CiteTrack*.xcarchive/Products/Applications/CiteTrack.app

# 检查Entitlements
codesign -d --entitlements :- ~/Library/Developer/Xcode/Archives/YYYY-MM-DD/CiteTrack*.xcarchive/Products/Applications/CiteTrack.app

# 检查是否包含Sparkle
ls ~/Library/Developer/Xcode/Archives/YYYY-MM-DD/CiteTrack*.xcarchive/Products/Applications/CiteTrack.app/Contents/Frameworks/
```

---

**祝您提交成功！** 🚀

