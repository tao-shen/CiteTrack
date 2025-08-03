# 🚨 CiteTrack Keychain 混乱状况分析

## 😱 **严重问题：发现5个密钥条目，4个不同的私钥！**

### 📋 **当前 Keychain 状况**

#### 1️⃣ `ed25519` (原始，正确的密钥)
- **账户名**: `ed25519`
- **私钥**: `ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=` ✅
- **创建时间**: 2025-07-14 12:43:46
- **状态**: ✅ **这是我们一直在用的正确密钥**

#### 2️⃣ `citetrack_new` (错误的密钥)
- **账户名**: `citetrack_new`  
- **私钥**: `p2yCNeNGwPfvWBdt9808i3CXulcdosbcABFAmMaw8KY=` ❌
- **创建时间**: 2025-07-21 10:50:35
- **状态**: ❌ **不同的私钥，会导致签名失败**

#### 3️⃣ `citetrack_official` (错误的密钥)
- **账户名**: `citetrack_official`
- **私钥**: `ffafmKbcYDA/dukS3dTBFeAFRpiyYdAm2s8w5xhFRKc=` ❌
- **创建时间**: 2025-07-21 11:16:56  
- **状态**: ❌ **不同的私钥，会导致签名失败**

#### 4️⃣ `citetrack_private_key` (正确的密钥)
- **账户名**: `citetrack_private_key`
- **私钥**: `ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=` ✅
- **创建时间**: 2025-07-21 15:32:07
- **状态**: ✅ **与原始密钥相同，正确**

#### 5️⃣ `citetrack_public_key` (对应的公钥)
- **账户名**: `citetrack_public_key`
- **公钥**: `NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=` ✅
- **创建时间**: 2025-07-21 15:32:07
- **状态**: ✅ **正确的公钥，对应原始私钥**

## 🔍 **问题分析**

### ❌ **错误的密钥来源**
在之前的操作过程中，可能发生了以下情况：
1. 生成了新的密钥对，保存为 `citetrack_new`
2. 又生成了另一个新密钥对，保存为 `citetrack_official`  
3. 最后才正确地备份了原始密钥为 `citetrack_private_key`

### 💥 **潜在危险**
- 如果误用错误的私钥签名，会导致 "improperly signed" 错误
- 用户无法从旧版本更新到用错误密钥签名的版本
- 破坏更新链的连续性

## 🛠️ **立即修复方案**

### 🎯 **当前正确的密钥对**
```
私钥: ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=
公钥: NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=
```

### ✅ **可以使用的条目**
- `ed25519` - 原始正确密钥
- `citetrack_private_key` - 正确的备份  
- `citetrack_public_key` - 正确的公钥

### ❌ **必须删除的错误条目**
- `citetrack_new` - 错误的私钥
- `citetrack_official` - 错误的私钥

### 🧹 **清理命令**
```bash
# 删除错误的密钥（谨慎执行！）
security delete-generic-password -a "citetrack_new"
security delete-generic-password -a "citetrack_official"
```

## 📝 **推荐使用方式**

### 🥇 **主要使用**
```bash
# 获取私钥用于签名
security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w
```

### 🥈 **备用方式**  
```bash
# 如果上面失败，使用原始条目
security find-generic-password -a "ed25519" -w
```

### 🏗️ **构建时使用**
```xml
<!-- Info.plist 中固定使用这个公钥 -->
<key>SUPublicEDKey</key>
<string>NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=</string>
```

## 🚨 **重要提醒**

1. **绝对不要使用** `citetrack_new` 或 `citetrack_official` 密钥
2. **只使用** `ed25519` 或 `citetrack_private_key` 密钥  
3. **立即清理错误的密钥**，避免将来误用
4. **验证所有已发布版本**使用的是正确的密钥签名

## ✅ **验证当前版本状态**

我们当前发布的 v1.1.3 和 v2.0.0 使用的签名：
- v1.1.3: `WAwrwF0kfqBbGvoxKU7EqP598nDL5tpMlSR8DBKMLm4RbbCQqO4MLcY+L+0dK+58QPsk/YWhoYw7GxgzfZZnCA==`
- v2.0.0: `6lFxIBWIWlI84+KkSbrMN0aySm252JdyJzHE8+XeG8rxItMnbESiaQpUDetETNdwQLzGkJ4oLZZmYYbIjOtfCw==`

这些签名是用正确的私钥 `ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=` 生成的，所以更新功能应该正常工作。

---

**结论**: 需要立即清理错误的密钥，只保留正确的密钥条目！