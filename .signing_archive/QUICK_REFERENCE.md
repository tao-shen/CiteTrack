# 🚀 CiteTrack 签名快速参考

## 🔑 核心密钥 (永远不要更改!)
```
私钥: ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=
公钥: NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=
```
**备份状态**: 🔐 已备份到 iCloud Keychain（端到端加密）  
**重要性**: 🚨 这对密钥是 CiteTrack 自动更新的核心，绝对不能丢失！

## 🔐 从 iCloud Keychain 获取密钥

### 🥇 推荐用法（标准方式）
```bash
# 获取私钥（签名用）- 推荐使用这个！
security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w

# 公钥直接使用（Info.plist 用）- 固定值！
NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=
```

### 🥈 备用方式（如果上面失败）
```bash
# 备用私钥获取方式
security find-generic-password -a "ed25519" -w
```

### ❓ Keychain 中的三个条目解释
- **`ed25519`**: 原始私钥条目（历史遗留）
- **`citetrack_private_key`**: 新的私钥条目 ✅ **用这个！**
- **`citetrack_public_key`**: 公钥条目（其实不需要，可从私钥推导）

## 🚨 发布新版本时必须做的事:

### 1️⃣ 构建时确保 Info.plist 包含:
```xml
<key>SUPublicEDKey</key>
<string>NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=</string>
```

### 2️⃣ 为 DMG 生成签名:
```bash
echo "ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=" | ./Frameworks/bin/sign_update YOUR_FILE.dmg
```

### 3️⃣ 在 appcast.xml 中更新:
- `sparkle:edSignature="生成的签名"`
- `length="文件字节大小"`

## 🆘 紧急修复:
如果出现签名错误，运行:
```bash
./.signing_archive/emergency_fix.sh YOUR_DMG_FILE.dmg
```

## 📋 检查清单:
- [ ] 构建脚本使用正确公钥
- [ ] DMG 文件已创建
- [ ] 签名已生成
- [ ] appcast.xml 已更新
- [ ] GitHub Release 已上传
- [ ] 测试更新功能

**记住**: 密钥对一旦确定就不要改变，否则会破坏整个更新链！