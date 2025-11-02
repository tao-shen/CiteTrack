# 🚀 App Store提交问题 - 快速修复指南

## ✅ 已完成的修复

我已经为您完成了以下修复：

### 1. 代码修改 ✓

**文件**: `macOS/Sources/MainAppDelegate.swift`
- 添加了条件编译，仅在非App Store版本中包含Sparkle
- App Store版本会自动跳过Sparkle初始化和"检查更新"菜单

**文件**: `macOS/Info.plist`
- 移除了`SUEnableAutomaticChecks`配置
- 保持沙盒权限配置正确

### 2. 工具脚本 ✓

**文件**: `macOS/scripts/prepare_app_store.sh`
- 自动查找最新的Archive
- 移除Sparkle框架
- 验证沙盒和签名
- 创建安全备份

### 3. 详细文档 ✓

**文件**: `macOS/APP_STORE_SUBMISSION_GUIDE.md`
- 完整的提交指南
- 常见问题解决方案
- 验证清单

---

## 🎯 接下来您需要做的（3步）

### 第1步：在Xcode中配置构建标志

1. 打开项目：
   ```bash
   open /Users/tao.shen/google_scholar_plugin/macOS/CiteTrack_macOS.xcodeproj
   ```

2. 选择项目文件（蓝色图标） → **CiteTrack** target → **Build Settings**

3. 搜索 **"Other Swift Flags"**

4. 在 **Release** 配置下，点击 **+** 添加：
   ```
   -D APP_STORE
   ```
   
   应该看到类似这样：
   ```
   Release: -D APP_STORE $(inherited)
   ```

5. （重要）搜索 **"Debug Information Format"**，确保：
   - **Debug**: `DWARF with dSYM File`
   - **Release**: `DWARF with dSYM File`

### 第2步：清理并重新Archive

1. 在Xcode中：
   - 按 **Shift + Cmd + K** 清理构建
   - 选择菜单：**Product** → **Archive**

2. 等待Archive完成

### 第3步：准备并上传

1. 运行准备脚本：
   ```bash
   cd /Users/tao.shen/google_scholar_plugin/macOS
   ./scripts/prepare_app_store.sh
   ```

2. 在Xcode Organizer中（**Window** → **Organizer**）：
   - 选择刚才的Archive
   - 点击 **Distribute App**
   - 选择 **App Store Connect**
   - 点击 **Upload**
   - 完成上传向导

---

## 🔍 验证修复是否生效

### 验证代码编译正确

运行Archive后，检查构建日志：

```bash
# 搜索编译标志
# 应该看到 -D APP_STORE 在Release构建中
```

### 验证Sparkle已移除

Archive完成后：

1. 打开 **Window** → **Organizer**
2. 右键点击Archive → **Show in Finder**
3. 右键点击Archive → **Show Package Contents**
4. 导航到：`Products/Applications/CiteTrack.app/Contents/Frameworks/`
5. **确认没有Sparkle.framework文件夹**

### 验证应用功能

如果您想测试App Store版本：

1. 导出应用：Organizer → Distribute App → Copy App
2. 运行导出的应用
3. 检查菜单栏 → 应该**没有**"检查更新"选项
4. 检查控制台输出 → 应该看到"App Store版本 - 自动更新已禁用"

---

## ❓ 常见问题

### Q: 为什么还是看到Sparkle错误？

**A**: 确保：
1. ✅ 已在Build Settings中添加 `-D APP_STORE`
2. ✅ 已清理构建（Shift+Cmd+K）
3. ✅ 使用Release配置Archive
4. ✅ 运行了prepare_app_store.sh脚本

### Q: dSYM错误还在？

**A**: 
1. 打开Xcode Build Settings
2. 搜索 "Debug Information Format"
3. 确保Release = "DWARF with dSYM File"
4. 清理并重新Archive

### Q: 上传时签名错误？

**A**: 
- Xcode会自动重新签名
- 确保您有有效的Developer ID证书
- 在Organizer上传时选择"Automatically manage signing"

### Q: 如何构建包含Sparkle的直接分发版本？

**A**: 
1. 在Build Settings中移除 `-D APP_STORE` 标志
2. Archive
3. Export选择"Developer ID"而不是"App Store"

---

## 📋 验证清单

在上传前确认：

- [ ] ✅ Build Settings → Other Swift Flags (Release) = `-D APP_STORE`
- [ ] ✅ Build Settings → Debug Information Format = `DWARF with dSYM File`
- [ ] ✅ 已清理并重新Archive
- [ ] ✅ 已运行 `prepare_app_store.sh`
- [ ] ✅ Archive中没有Sparkle.framework
- [ ] ✅ Info.plist包含`LSApplicationCategoryType`
- [ ] ✅ Entitlements启用App Sandbox

---

## 🆘 如果还有问题

### 查看详细日志

```bash
# Xcode构建日志
# 在Xcode中：View → Navigators → Reports → 选择最新的Archive

# 准备脚本输出
# 运行脚本时会显示详细信息
```

### 重置并重试

```bash
# 完全清理
rm -rf ~/Library/Developer/Xcode/DerivedData/CiteTrack-*

# 在Xcode中重新Archive
```

### 手动移除Sparkle

如果脚本无法运行：

```bash
# 找到最新Archive
cd ~/Library/Developer/Xcode/Archives
ls -lt

# 手动删除Sparkle
cd [最新Archive路径]/Products/Applications/CiteTrack.app/Contents/Frameworks
rm -rf Sparkle.framework
```

---

## 📞 需要更多帮助？

查看完整指南：
```bash
open /Users/tao.shen/google_scholar_plugin/macOS/APP_STORE_SUBMISSION_GUIDE.md
```

或访问Apple文档：
- [App Store Connect帮助](https://help.apple.com/app-store-connect/)
- [App Sandbox文档](https://developer.apple.com/documentation/security/app_sandbox)

---

## 🎉 成功标志

当您成功上传后，您会看到：
- ✅ App Store Connect显示"Processing"状态
- ✅ 10-30分钟后状态变为"Ready to Submit"
- ✅ 没有沙盒或dSYM错误

**祝您提交顺利！** 🚀

