# Apple 公证（Notarization）完整指南

## 🎯 目标
解决 "Apple could not verify CiteTrack is free of malware" 错误，获得 Apple 官方认证。

## 📋 前置要求

### 1. Apple Developer 账户
- **个人开发者**: $99/年
- **企业开发者**: $299/年
- 注册地址: https://developer.apple.com/programs/

### 2. 开发者证书
需要以下证书：
- **Developer ID Application Certificate** - 用于签名应用
- **Developer ID Installer Certificate** - 用于签名安装包（可选）

## 🛠️ 完整流程

### 步骤 1: 获取开发者证书
```bash
# 1. 在 Keychain Access 中生成证书签名请求 (CSR)
# 2. 在 Apple Developer 网站上传 CSR
# 3. 下载并安装证书到 Keychain
```

### 步骤 2: 使用开发者证书签名
```bash
# 查看可用的签名身份
security find-identity -v -p codesigning

# 使用开发者证书签名
codesign --force --deep --sign "Developer ID Application: Your Name (TEAM_ID)" CiteTrack.app

# 验证签名
codesign --verify --deep --strict CiteTrack.app
spctl --assess --type exec CiteTrack.app
```

### 步骤 3: 公证应用
```bash
# 创建 ZIP 包用于公证
ditto -c -k --keepParent CiteTrack.app CiteTrack.zip

# 提交公证（需要 App Store Connect API 密钥）
xcrun notarytool submit CiteTrack.zip \
  --keychain-profile "notarytool-profile" \
  --wait

# 或使用 Apple ID 和应用专用密码
xcrun notarytool submit CiteTrack.zip \
  --apple-id "your-apple-id@example.com" \
  --password "app-specific-password" \
  --team-id "YOUR_TEAM_ID" \
  --wait
```

### 步骤 4: 装订公证票据
```bash
# 公证成功后，装订票据到应用
xcrun stapler staple CiteTrack.app

# 验证装订
xcrun stapler validate CiteTrack.app
spctl --assess --type exec CiteTrack.app
```

## 🚀 自动化脚本

### 完整的签名和公证脚本
```bash
#!/bin/bash

# 配置
DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
APPLE_ID="your-apple-id@example.com"
APP_PASSWORD="app-specific-password"
TEAM_ID="YOUR_TEAM_ID"
APP_NAME="CiteTrack"

echo "🔐 开始签名和公证流程..."

# 1. 签名应用
echo "📝 签名应用..."
codesign --force --deep --sign "$DEVELOPER_ID" "$APP_NAME.app"

if [ $? -ne 0 ]; then
    echo "❌ 签名失败"
    exit 1
fi

# 2. 验证签名
echo "✅ 验证签名..."
codesign --verify --deep --strict "$APP_NAME.app"
spctl --assess --type exec "$APP_NAME.app"

# 3. 创建公证包
echo "📦 创建公证包..."
ditto -c -k --keepParent "$APP_NAME.app" "$APP_NAME.zip"

# 4. 提交公证
echo "🚀 提交公证..."
xcrun notarytool submit "$APP_NAME.zip" \
  --apple-id "$APPLE_ID" \
  --password "$APP_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

if [ $? -ne 0 ]; then
    echo "❌ 公证失败"
    exit 1
fi

# 5. 装订票据
echo "📎 装订公证票据..."
xcrun stapler staple "$APP_NAME.app"

# 6. 最终验证
echo "🔍 最终验证..."
xcrun stapler validate "$APP_NAME.app"
spctl --assess --type exec "$APP_NAME.app"

echo "✅ 公证完成！"
```

## 💰 成本考虑

### Apple Developer Program
- **年费**: $99 USD
- **包含**: 代码签名证书、公证服务、App Store 分发

### 免费替代方案
如果不想付费，可以：
1. **提供安装说明** - 教用户如何绕过安全警告
2. **使用 ad-hoc 签名** - 当前的解决方案
3. **开源分发** - 让用户自行编译

## 📱 用户临时解决方案

### 方法 1: 右键打开
1. 右键点击 CiteTrack.app
2. 选择"打开"
3. 在弹出的对话框中点击"打开"

### 方法 2: 系统设置
1. 系统偏好设置 → 安全性与隐私
2. 在"通用"标签页中点击"仍要打开"

### 方法 3: 终端命令
```bash
# 移除隔离属性
xattr -dr com.apple.quarantine /Applications/CiteTrack.app

# 或者临时禁用 Gatekeeper（不推荐）
sudo spctl --master-disable
```

## 🎯 推荐方案

### 对于个人项目
1. **当前方案**: 继续使用 ad-hoc 签名，提供用户说明
2. **长期方案**: 考虑购买 Developer Program 进行公证

### 对于商业项目
1. **必须**: 购买 Apple Developer Program
2. **完整流程**: 签名 → 公证 → 分发
3. **用户体验**: 无安全警告，直接运行

## 📋 检查清单

- [ ] 注册 Apple Developer Program
- [ ] 生成并下载开发者证书
- [ ] 配置 App Store Connect API 密钥
- [ ] 修改构建脚本添加公证流程
- [ ] 测试完整的签名和公证流程
- [ ] 验证最终应用可以无警告运行

## 🔗 相关链接

- [Apple Developer Program](https://developer.apple.com/programs/)
- [公证指南](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [代码签名指南](https://developer.apple.com/documentation/security/code_signing_services) 