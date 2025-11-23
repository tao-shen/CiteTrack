# ✅ 修复完成！

## 🎯 问题已解决

修复脚本已经更新，现在可以正确为所有 Sparkle 组件应用 App Sandbox entitlements。

## 📝 使用步骤

### 1. Archive 构建

在 Xcode 中：
```
Product → Archive
```

### 2. 运行修复脚本

Archive 完成后，**在点击 "Distribute App" 之前**，运行：

```bash
cd /Users/tao.shen/google_scholar_plugin/macOS
./scripts/fix_archive_entitlements.sh
```

脚本会自动：
- ✅ 找到最新的 Archive
- ✅ 检测签名身份
- ✅ 为所有 Sparkle 组件添加 App Sandbox entitlements
- ✅ 验证签名和 entitlements

### 3. 验证修复

运行脚本后，应该看到：
```
✅ Autoupdate signed and verified
✅ Updater executable signed and verified
✅ Updater.app bundle signed and verified
✅ Downloader executable signed and verified
✅ Downloader.xpc bundle signed and verified
✅ Installer executable signed and verified
✅ Installer.xpc bundle signed and verified
✅ Sparkle framework components signing complete!
```

### 4. 提交到 App Store

1. 在 Xcode Organizer 中
2. 选择修复后的 Archive
3. 点击 **Distribute App** → **App Store Connect**
4. 完成上传

---

## ⚠️ 重要提示

### 操作顺序（必须遵守）

1. ✅ Archive 构建
2. ✅ **运行修复脚本**（关键步骤！）
3. ✅ 验证脚本输出
4. ✅ 在 Xcode Organizer 中提交

**不要**：
- ❌ Archive 完成后立即点击 "Distribute App"
- ❌ 跳过修复脚本步骤
- ❌ 使用旧的、未修复的 Archive

---

## 🔍 验证修复

运行修复脚本后，可以验证 entitlements：

```bash
ARCHIVE_PATH="path/to/your.xcarchive"
codesign -d --entitlements :/tmp/check.plist "$ARCHIVE_PATH/Products/Applications/CiteTrack.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>&1
cat /tmp/check.plist | grep -A 1 "app-sandbox"
```

应该看到：
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

---

## 📋 关于 dSYM 警告

dSYM 警告是**正常的**，不会阻止提交：
- Sparkle 是第三方框架，没有源代码
- 无法生成 dSYM 文件
- App Store 通常会接受这些警告

---

## 🆘 如果仍然失败

如果按照上述步骤操作后仍然失败：

1. **检查操作顺序**：确保在运行脚本后才点击 "Distribute App"
2. **重新 Archive**：删除旧的 Archive，重新构建并运行脚本
3. **检查签名身份**：确保使用正确的开发者证书
4. **考虑移除 Sparkle**：如果只通过 App Store 分发，移除 Sparkle 是最简单的解决方案

---

## 📚 相关文档

- `重要：修复脚本使用说明.md` - 详细使用说明
- `操作检查清单.md` - 提交前检查清单
- `最终解决方案.md` - 完整的解决方案说明

