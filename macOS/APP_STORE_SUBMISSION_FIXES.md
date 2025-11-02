# App Store 提交问题修复指南

## 已修复的问题

### 1. ✅ LSApplicationCategoryType 缺失
**问题**: Info.plist必须包含LSApplicationCategoryType键
**解决方案**: 已在Info.plist中添加：
```xml
<key>LSApplicationCategoryType</key>
<string>public.app-category.productivity</string>
```

### 2. ✅ App Sandbox 未启用
**问题**: 应用沙盒未启用，所有可执行文件都需要沙盒权限
**解决方案**: 已在CiteTrack.entitlements中启用：
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

### 3. 🔧 dSYM 符号上传失败
**问题**: Archive缺少dSYM文件
**解决方案**: 需要手动在Xcode中设置

## 手动修复步骤

### 在Xcode中修复dSYM问题：

1. **打开项目**: 打开 `CiteTrack_macOS.xcodeproj`

2. **选择Target**: 选择项目根节点，然后选择 `CiteTrack` target

3. **进入Build Settings**: 点击 "Build Settings" 标签

4. **设置Debug Information Format**:
   - 搜索 "Debug Information Format"
   - 将 **Debug** 设置为 "DWARF with dSYM File"
   - 将 **Release** 设置为 "DWARF with dSYM File"

5. **禁用符号剥离**:
   - 搜索 "Strip Debug Symbols During Copy"
   - 将 **Release** 设置为 "NO"

6. **清理并重新构建**:
   - 按 `Cmd+Shift+K` 清理构建文件夹
   - 重新Archive项目

### 验证修复：

1. **检查Info.plist**:
   ```bash
   plutil -p Info.plist | grep LSApplicationCategoryType
   ```
   应该显示: `"LSApplicationCategoryType" => "public.app-category.productivity"`

2. **检查Entitlements**:
   ```bash
   plutil -p CiteTrack.entitlements | grep app-sandbox
   ```
   应该显示: `"com.apple.security.app-sandbox" => true`

3. **检查dSYM文件**:
   Archive后，在 `~/Library/Developer/Xcode/Archives/` 中找到最新的archive
   检查是否包含 `.dSYM` 文件夹

## 额外的App Store要求

### 隐私政策
确保您的应用有隐私政策，并在App Store Connect中提供链接。

### 应用图标
确保应用图标符合App Store要求：
- 1024x1024像素
- 无透明度
- 符合设计指南

### 应用描述
准备详细的应用描述，包括：
- 功能说明
- 截图
- 关键词

## 常见问题解决

### 如果dSYM问题仍然存在：

1. **检查第三方框架**:
   - Sparkle框架需要单独的dSYM文件
   - 确保所有框架都启用了dSYM生成

2. **手动添加dSYM**:
   - 在Archive时，确保选择 "Include dSYM files"
   - 检查Organizer中的dSYM文件

3. **重新构建**:
   - 完全清理项目
   - 删除DerivedData
   - 重新Archive

### 如果沙盒问题仍然存在：

1. **检查所有可执行文件**:
   - 主应用
   - Sparkle框架中的可执行文件
   - 所有XPC服务

2. **添加必要的权限**:
   - 网络访问
   - 文件访问
   - 用户选择的文件访问

## 提交前检查清单

- [ ] Info.plist包含LSApplicationCategoryType
- [ ] 启用App Sandbox
- [ ] 生成dSYM文件
- [ ] 应用图标符合要求
- [ ] 隐私政策已准备
- [ ] 应用描述已完善
- [ ] 测试所有功能
- [ ] 清理构建并重新Archive

## 联系支持

如果仍有问题，请检查：
1. Apple Developer文档
2. App Store Connect帮助
3. Xcode构建日志中的详细错误信息
