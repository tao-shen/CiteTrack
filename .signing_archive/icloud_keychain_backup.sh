#!/bin/bash

# CiteTrack 签名密钥 iCloud Keychain 备份脚本
# 将 EdDSA 密钥安全保存到 iCloud 钥匙串

echo "🔐 CiteTrack 签名密钥 iCloud Keychain 备份"
echo ""

# CiteTrack 的核心密钥
PRIVATE_KEY="ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik="
PUBLIC_KEY="NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw="

echo "🔑 准备备份以下密钥到 iCloud Keychain:"
echo "私钥: $PRIVATE_KEY"
echo "公钥: $PUBLIC_KEY"
echo ""

# 检查是否已经存在
echo "🔍 检查现有密钥..."
EXISTING_PRIVATE=$(security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w 2>/dev/null)
EXISTING_PUBLIC=$(security find-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key" -w 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$EXISTING_PRIVATE" ]; then
    echo "⚠️  发现现有的 CiteTrack 私钥"
    if [ "$EXISTING_PRIVATE" = "$PRIVATE_KEY" ]; then
        echo "✅ 现有私钥匹配，无需更新"
    else
        echo "⚠️  现有私钥不匹配，将更新"
        security delete-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" 2>/dev/null
    fi
else
    echo "ℹ️  未找到现有私钥，将新建"
fi

if [ $? -eq 0 ] && [ -n "$EXISTING_PUBLIC" ]; then
    echo "⚠️  发现现有的 CiteTrack 公钥"
    if [ "$EXISTING_PUBLIC" = "$PUBLIC_KEY" ]; then
        echo "✅ 现有公钥匹配，无需更新"
    else
        echo "⚠️  现有公钥不匹配，将更新"
        security delete-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key" 2>/dev/null
    fi
else
    echo "ℹ️  未找到现有公钥，将新建"
fi

echo ""

# 保存私钥到 iCloud Keychain
echo "💾 保存私钥到 iCloud Keychain..."
security add-generic-password \
    -a "citetrack_private_key" \
    -s "CiteTrack EdDSA Private Key" \
    -w "$PRIVATE_KEY" \
    -D "CiteTrack 自动更新签名私钥 - 用于签名DMG文件" \
    -j "CiteTrack EdDSA private key for signing app updates. CRITICAL: Do not delete!" \
    -T "" \
    -U

if [ $? -eq 0 ]; then
    echo "✅ 私钥保存成功"
else
    echo "❌ 私钥保存失败"
    exit 1
fi

# 保存公钥到 iCloud Keychain
echo "💾 保存公钥到 iCloud Keychain..."
security add-generic-password \
    -a "citetrack_public_key" \
    -s "CiteTrack EdDSA Public Key" \
    -w "$PUBLIC_KEY" \
    -D "CiteTrack 自动更新签名公钥 - 用于Info.plist中的SUPublicEDKey" \
    -j "CiteTrack EdDSA public key for app Info.plist SUPublicEDKey. Use: NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw=" \
    -T "" \
    -U

if [ $? -eq 0 ]; then
    echo "✅ 公钥保存成功"
else
    echo "❌ 公钥保存失败"
    exit 1
fi

echo ""
echo "🎉 密钥备份完成！"
echo ""
echo "📱 iCloud Keychain 同步信息:"
echo "• 密钥会自动同步到你的所有 Apple 设备"
echo "• iPhone、iPad、Mac 等都可以访问"
echo "• 受 Apple ID 双因素认证保护"
echo "• 端到端加密存储"
echo ""
echo "🔍 查看保存的密钥:"
echo "macOS: 钥匙串访问 App → 登录 → 种类: 密码"
echo "搜索: 'CiteTrack EdDSA'"
echo ""
echo "📋 获取密钥命令:"
echo "私钥: security find-generic-password -a 'citetrack_private_key' -s 'CiteTrack EdDSA Private Key' -w"
echo "公钥: security find-generic-password -a 'citetrack_public_key' -s 'CiteTrack EdDSA Public Key' -w"
echo ""
echo "⚠️  重要提醒:"
echo "• 请确保你的 Apple ID 启用了双因素认证"
echo "• 请勿在钥匙串访问中删除这些密钥"
echo "• 密钥名称包含 'CiteTrack EdDSA' 便于识别"