#!/bin/bash

# CiteTrack Keychain 密钥备份脚本
# 备份系统 Keychain 中的 EdDSA 私钥

echo "🔐 CiteTrack Keychain 密钥备份"
echo ""

# 尝试从 Keychain 获取私钥
echo "🔍 从 macOS Keychain 获取私钥..."

# 尝试不同的账户名
ACCOUNTS=("ed25519" "citetrack_official" "EdDSA")

for account in "${ACCOUNTS[@]}"; do
    echo "尝试账户: $account"
    PRIVATE_KEY=$(security find-generic-password -a "$account" -w 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$PRIVATE_KEY" ]; then
        echo "✅ 找到私钥 (账户: $account)"
        echo "私钥: $PRIVATE_KEY"
        
        # 验证这是否是我们期望的私钥
        if [ "$PRIVATE_KEY" = "ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik=" ]; then
            echo "✅ 验证通过 - 这是正确的 CiteTrack 私钥"
        else
            echo "⚠️  这不是 CiteTrack 使用的私钥"
        fi
        
        echo ""
    else
        echo "❌ 账户 $account 中未找到密钥"
    fi
done

echo ""
echo "📝 当前 CiteTrack 使用的密钥:"
echo "私钥: ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik="
echo "公钥: NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw="
echo ""
echo "💡 如果需要重新添加到 Keychain:"
echo "security add-generic-password -a 'ed25519' -s 'EdDSA' -w 'ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik='"