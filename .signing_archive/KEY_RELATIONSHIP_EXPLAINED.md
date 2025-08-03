# 🔑 CiteTrack Keychain 密钥关系详解

## 📋 现状：Keychain 中的三个条目

### 1. `ed25519` 账户（原始密钥）
- **账户名**: `ed25519`
- **服务名**: `https://sparkle-project.org`
- **内容**: `ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=` （私钥）
- **作用**: 历史遗留，最初创建的条目

### 2. `citetrack_private_key`（新私钥备份）
- **账户名**: `citetrack_private_key`
- **服务名**: `CiteTrack EdDSA Private Key`
- **内容**: `ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=` （私钥）
- **作用**: 专门为 CiteTrack 创建的私钥备份

### 3. `citetrack_public_key`（新公钥备份）
- **账户名**: `citetrack_public_key`
- **服务名**: `CiteTrack EdDSA Public Key`
- **内容**: `NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=` （公钥）
- **作用**: 专门为 CiteTrack 创建的公钥备份

## 🤔 问题解释

### 为什么会有三个条目？
1. **历史原因**: 原始的 `ed25519` 条目是最初创建的
2. **混淆备份**: 我的脚本错误地把公钥也作为"密钥"保存了
3. **冗余备份**: 实际上只需要保存私钥，公钥可以从私钥推导

### 它们的关系是什么？
```
私钥 ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=
  ↓ (通过算法推导)
公钥 NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=
```

- `ed25519` 和 `citetrack_private_key` 存储的是**同一个私钥**
- `citetrack_public_key` 存储的是对应的**公钥**
- 公钥可以从私钥计算得出，所以技术上只需要保存私钥

## 🎯 下次应该用哪个？

### 🥇 **首选方案（推荐）**
```bash
# 使用新的 CiteTrack 专用私钥条目
security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w
```

**优点**:
- 命名清晰，容易识别
- 专门为 CiteTrack 创建
- 有详细的中文描述

### 🥈 **备用方案**
```bash
# 使用原始的 ed25519 条目
security find-generic-password -a "ed25519" -w
```

**优点**:
- 历史连续性
- 命令更简短

### ❌ **不要使用**
```bash
# 不要用公钥条目来签名（这是错误的）
security find-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key" -w
```

## 📝 标准使用流程

### 🔐 签名 DMG 文件时
```bash
# 推荐用法
PRIVATE_KEY=$(security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w)
echo "$PRIVATE_KEY" | ./Frameworks/bin/sign_update YOUR_FILE.dmg
```

### 🏗️ 构建应用时（Info.plist）
```bash
# 获取公钥（用于 SUPublicEDKey）
PUBLIC_KEY=$(security find-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key" -w)

# 或者从私钥推导公钥
PRIVATE_KEY=$(security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w)
PUBLIC_KEY=$(cd Frameworks/bin && echo "$PRIVATE_KEY" | ./generate_keys -p)
```

## 🧹 清理建议

### 选项1：保持现状（推荐）
- 保留所有三个条目作为冗余备份
- 使用 `citetrack_private_key` 作为主要条目

### 选项2：精简清理
- 删除 `ed25519` 原始条目（历史遗留）
- 删除 `citetrack_public_key` 条目（可从私钥推导）
- 只保留 `citetrack_private_key` 条目

### 清理命令（谨慎使用）
```bash
# 删除原始条目（可选）
security delete-generic-password -a "ed25519"

# 删除公钥条目（可选，因为可以从私钥推导）
security delete-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key"
```

## 🎯 **最终建议**

### 💡 **日常使用**
- **签名时**: 使用 `citetrack_private_key` 条目
- **构建时**: 使用固定的公钥字符串 `NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=`

### 📝 **更新脚本**
```bash
# 标准获取私钥的方法
get_citetrack_private_key() {
    security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w 2>/dev/null || \
    security find-generic-password -a "ed25519" -w 2>/dev/null || \
    echo "ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik="
}
```

这样即使某个条目丢失，也有备用方案！