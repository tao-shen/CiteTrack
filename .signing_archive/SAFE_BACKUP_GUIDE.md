# 🔐 CiteTrack 签名档案安全备份指南

## ⚠️ 风险等级评估

### 🔴 绝对不能做
- ❌ 提交到公开GitHub仓库
- ❌ 提交到任何公开代码平台
- ❌ 发送到聊天工具或邮件
- ❌ 存储在不加密的云盘

### 🟡 中等风险（谨慎使用）
- ⚠️ 私有GitHub仓库（账户被黑的风险）
- ⚠️ 企业内网Git服务器
- ⚠️ 其他云Git服务的私有仓库

### 🟢 推荐的安全做法
- ✅ 加密后存储到云盘
- ✅ 本地多地点备份（U盘、移动硬盘）
- ✅ 密码管理器备份关键信息
- ✅ 纸质备份（极端情况）

## 🛡️ 安全备份方案

### 方案1：GPG加密备份（推荐）
```bash
# 1. 创建加密备份
cd /Users/tao.shen/google_scholar_plugin
tar -czf citetrack_signing.tar.gz .signing_archive/
gpg -c citetrack_signing.tar.gz

# 2. 安全存储 citetrack_signing.tar.gz.gpg
# - 上传到iCloud/Google Drive/Dropbox
# - 复制到U盘
# - 发送到个人邮箱

# 3. 恢复时解密
gpg -d citetrack_signing.tar.gz.gpg > citetrack_signing.tar.gz
tar -xzf citetrack_signing.tar.gz
```

### 方案2：分离式备份（最安全）
```bash
# 分开备份：
# 1. 公开信息 → 可以放到私有Git仓库
cp -r .signing_archive .signing_archive_public
rm .signing_archive_public/keys.txt  # 移除私钥

# 2. 私钥信息 → 单独加密保存
echo "ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=" | gpg -c > private_key.gpg

# 3. 公钥信息 → 可以明文备份
echo "NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=" > public_key.txt
```

### 方案3：多重备份策略
1. **本地备份**: 时光机、手动复制到外置硬盘
2. **加密云备份**: GPG加密后上传云盘
3. **纸质备份**: 关键密钥手写保存（安全但不便）
4. **密码管理器**: 1Password、Bitwarden等

## 🎯 具体操作建议

### 立即执行（必须）：
1. 复制整个`.signing_archive/`文件夹到U盘
2. 把关键密钥记录到密码管理器
3. 手机拍照保存`QUICK_REFERENCE.md`内容

### 长期方案（推荐）：
1. 定期GPG加密备份到云盘
2. 每发布新版本更新备份
3. 定期测试备份恢复流程

## ❌ 风险案例

### 真实风险：
- 2021年：多个开发者的GitHub私有仓库被黑，API密钥泄露
- 2022年：某知名软件的更新私钥被盗，攻击者发布恶意更新
- 经常发生：开发者误将私钥提交到公开仓库

### 如果私钥泄露的后果：
1. 攻击者可以签名恶意更新
2. 用户电脑可能被感染恶意软件
3. 你需要吊销所有已发布的版本
4. 用户失去对软件的信任
5. 法律和声誉损失

## 🔧 紧急应对

### 如果私钥已经泄露：
1. 立即生成新的密钥对
2. 更新所有版本的公钥
3. 吊销所有旧版本
4. 通知用户手动下载新版本
5. 发布安全公告

## 📝 检查清单

每次备份前检查：
- [ ] 备份文件是否加密
- [ ] 存储位置是否安全
- [ ] 是否有多个备份副本
- [ ] 恢复流程是否测试过
- [ ] 团队成员是否知道备份位置

记住：**安全性 > 便利性**，私钥一旦泄露就无法挽回！