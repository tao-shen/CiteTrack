# CiteTrack Sparkle 签名档案 🔐

## 🚨 重要提示
**这个文件夹包含了 CiteTrack 自动更新系统的核心签名信息，务必妥善保管！**

## 📋 签名密钥信息

### EdDSA 密钥对 ⭐️ **核心资产**
- **私钥**: `ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=`
- **公钥**: `NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=`
- **密钥来源**: 原始生成，现保存在 iCloud Keychain
- **存储位置**: 🔐 iCloud 钥匙串 - 自动同步到所有设备
- **备份状态**: ☁️ 已备份到 iCloud Keychain（端到端加密）
- **访问方式**: `security find-generic-password -a "citetrack_private_key" -w`
- **重要性**: 🚨 **绝对不能丢失** - 丢失将导致无法发布更新

### 当前版本签名记录
- **v1.1.3 签名**: `WAwrwF0kfqBbGvoxKU7EqP598nDL5tpMlSR8DBKMLm4RbbCQqO4MLcY+L+0dK+58QPsk/YWhoYw7GxgzfZZnCA==`
- **v2.0.0 签名**: `6lFxIBWIWlI84+KkSbrMN0aySm252JdyJzHE8+XeG8rxItMnbESiaQpUDetETNdwQLzGkJ4oLZZmYYbIjOtfCw==`

## 🛠️ 使用方法

### 为新版本生成签名
```bash
# 1. 生成新版本的 DMG 文件
./scripts/build_charts.sh  # 或其他构建脚本

# 2. 创建 DMG
./scripts/create_vX.X.X_dmg.sh

# 3. 生成签名（替换 YOUR_DMG_FILE.dmg）
echo "ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=" | ./Frameworks/bin/sign_update YOUR_DMG_FILE.dmg

# 4. 将输出的签名和文件大小更新到 appcast.xml
```

### Info.plist 配置
确保在所有版本的 Info.plist 中包含：
```xml
<key>SUPublicEDKey</key>
<string>NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=</string>
```

## ⚠️ 关键注意事项

### 1. 密钥一致性
- **永远使用相同的密钥对**进行签名
- Info.plist 中的公钥必须与签名私钥匹配
- 不要随意更换密钥，否则会破坏更新链

### 2. 更新链完整性
- 每个版本都必须包含 `SUPublicEDKey`
- 每个 appcast.xml 条目都必须包含 `sparkle:edSignature`
- 文件大小必须准确（`length` 属性）

### 3. 构建脚本更新
当创建新版本时，确保构建脚本中包含正确的公钥：
- `scripts/build_charts.sh`（v2.0.0 及以后版本）
- `scripts/build_v1.1.3.sh`（v1.1.3 版本）

## 🔍 故障排除

### "The update is improperly signed" 错误
这个错误通常由以下原因引起：
1. **密钥不匹配**: Info.plist 中的公钥与签名私钥不是一对
2. **缺少签名**: appcast.xml 中缺少 `sparkle:edSignature`
3. **文件大小错误**: `length` 属性与实际 DMG 大小不符

### 验证签名
```bash
# 验证签名是否正确
echo "ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=" | ./Frameworks/bin/sign_update YOUR_DMG_FILE.dmg --verify YOUR_SIGNATURE
```

## 📝 版本发布检查清单

发布新版本时，请检查：
- [ ] 构建脚本包含正确的 SUPublicEDKey
- [ ] DMG 文件已创建并验证
- [ ] 使用正确私钥生成签名
- [ ] appcast.xml 更新了新签名和文件大小
- [ ] GitHub Release 上传了新 DMG 文件
- [ ] 从旧版本测试更新功能

## 🗂️ 相关文件位置
- **构建脚本**: `scripts/build_*.sh`
- **签名工具**: `Frameworks/bin/sign_update`
- **更新配置**: `appcast.xml`
- **GitHub Release**: https://github.com/tao-shen/CiteTrack/releases

---
**最后更新**: 2024年7月21日  
**当前版本**: v2.0.0  
**签名状态**: ✅ 正常工作
**备份位置**: ☁️ iCloud Drive/CiteTrack_Signing_Backup/

## 🔐 iCloud Keychain 密钥管理

### 快速备份到 iCloud Keychain
运行备份脚本将密钥保存到 iCloud 钥匙串：
```bash
./.signing_archive/icloud_keychain_backup.sh
```

### 密钥管理命令
```bash
# 管理脚本 - 一键管理所有密钥操作
./.signing_archive/keychain_management.sh backup  # 备份密钥
./.signing_archive/keychain_management.sh get     # 获取密钥
./.signing_archive/keychain_management.sh verify  # 验证密钥
./.signing_archive/keychain_management.sh list    # 列出密钥
```

### 直接访问命令
```bash
# 获取私钥（用于签名）
security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w

# 获取公钥（用于 Info.plist）
security find-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key" -w
```

### 🔐 iCloud Keychain 优势
- ✅ **端到端加密**: Apple 无法解密你的密钥
- ✅ **自动同步**: 在所有 Apple 设备间自动同步
- ✅ **双因素认证**: 受 Apple ID 双因素认证保护
- ✅ **系统级安全**: 集成到 macOS/iOS 安全架构
- ✅ **跨设备访问**: iPhone、iPad、Mac 都能访问
- ✅ **无需额外应用**: 使用系统原生钥匙串服务

### 在其他设备查看
- **Mac**: 钥匙串访问 App → 搜索 "CiteTrack EdDSA"
- **iPhone/iPad**: 设置 → 密码 → 搜索 "CiteTrack"
- **命令行**: 使用上述 `security` 命令