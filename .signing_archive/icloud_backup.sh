#!/bin/bash

# CiteTrack 签名密钥 iCloud 备份脚本
# 将关键签名信息安全备份到 iCloud

echo "☁️  CiteTrack 签名密钥 iCloud 备份"
echo ""

# 检查 iCloud Drive 路径
ICLOUD_PATH="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
if [ ! -d "$ICLOUD_PATH" ]; then
    echo "❌ iCloud Drive 未启用或路径不存在"
    echo "请先在系统偏好设置中启用 iCloud Drive"
    exit 1
fi

# 创建 CiteTrack 备份目录
BACKUP_DIR="$ICLOUD_PATH/CiteTrack_Signing_Backup"
mkdir -p "$BACKUP_DIR"

echo "📁 备份目录: $BACKUP_DIR"
echo ""

# 创建密钥信息文件
echo "🔑 创建密钥备份文件..."

cat > "$BACKUP_DIR/CiteTrack_Keys.txt" << 'EOF'
# CiteTrack EdDSA 签名密钥对
# 备份日期: $(date '+%Y-%m-%d %H:%M:%S')
# 重要性: ⭐️⭐️⭐️⭐️⭐️ 绝对不能丢失！

## 核心密钥对（永远不要更改）
PRIVATE_KEY=ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=
PUBLIC_KEY=NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=

## 使用方法
# 1. 构建时在 Info.plist 中使用公钥:
#    <key>SUPublicEDKey</key>
#    <string>NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=</string>

# 2. 为 DMG 文件生成签名:
#    echo "ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=" | ./Frameworks/bin/sign_update YOUR_FILE.dmg

## 当前版本状态
# v1.1.3: CiteTrack-Professional-v1.1.3.dmg
# v2.0.0: CiteTrack-Charts-Professional-v2.0.0.dmg
# 状态: ✅ 正常工作，签名验证通过

## 紧急恢复
# 如果出现 "The update is improperly signed" 错误:
# 1. 确保 Info.plist 包含上述公钥
# 2. 使用上述私钥重新签名 DMG
# 3. 更新 appcast.xml 中的签名和文件大小

## 安全提醒
# ⚠️  这个文件包含签名私钥，请勿分享给他人
# ⚠️  如果需要协作，只分享公钥部分
# ⚠️  定期检查 iCloud 同步状态
EOF

# 复制快速参考文件
cp .signing_archive/QUICK_REFERENCE.md "$BACKUP_DIR/"

# 复制完整的签名档案（不包含可执行文件）
cp .signing_archive/README.md "$BACKUP_DIR/"
cp .signing_archive/version_signatures.txt "$BACKUP_DIR/"
cp .signing_archive/build_templates.txt "$BACKUP_DIR/"

echo "✅ 备份完成！文件已保存到:"
echo "   $BACKUP_DIR"
echo ""
echo "📱 备份内容:"
echo "   • CiteTrack_Keys.txt (核心密钥信息)"
echo "   • QUICK_REFERENCE.md (快速参考)"
echo "   • README.md (完整说明)"
echo "   • version_signatures.txt (版本记录)"
echo "   • build_templates.txt (构建模板)"
echo ""
echo "☁️  这些文件会自动同步到:"
echo "   • 你的其他 Mac 设备"
echo "   • iPhone/iPad iCloud Drive 应用"
echo "   • iCloud.com 网页版"
echo ""
echo "🔐 安全提醒:"
echo "   • iCloud 备份已加密存储"
echo "   • 请勿在不安全的设备上打开这些文件"
echo "   • 建议定期检查同步状态"
echo ""
echo "📱 在 iPhone 上查看:"
echo "   文件 App → iCloud Drive → CiteTrack_Signing_Backup"