#!/bin/bash

# CiteTrack iCloud Keychain 密钥管理脚本
# 管理 iCloud 钥匙串中的 CiteTrack 签名密钥

echo "🔐 CiteTrack iCloud Keychain 密钥管理"
echo ""

function show_help() {
    echo "使用方法:"
    echo "  $0 backup    - 备份密钥到 iCloud Keychain"
    echo "  $0 get       - 获取已保存的密钥"
    echo "  $0 verify    - 验证密钥完整性"
    echo "  $0 list      - 列出所有 CiteTrack 密钥"
    echo "  $0 remove    - 删除 iCloud Keychain 中的密钥"
    echo "  $0 help      - 显示帮助信息"
}

function backup_keys() {
    echo "🔄 执行 iCloud Keychain 备份..."
    ./icloud_keychain_backup.sh
}

function get_keys() {
    echo "🔍 从 iCloud Keychain 获取密钥:"
    echo ""
    
    echo "私钥:"
    PRIVATE_KEY=$(security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$PRIVATE_KEY" ]; then
        echo "✅ $PRIVATE_KEY"
    else
        echo "❌ 未找到私钥"
    fi
    
    echo ""
    echo "公钥:"
    PUBLIC_KEY=$(security find-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key" -w 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$PUBLIC_KEY" ]; then
        echo "✅ $PUBLIC_KEY"
    else
        echo "❌ 未找到公钥"
    fi
    
    echo ""
    if [ -n "$PRIVATE_KEY" ] && [ -n "$PUBLIC_KEY" ]; then
        echo "📋 使用方法:"
        echo "签名命令: echo \"$PRIVATE_KEY\" | ./Frameworks/bin/sign_update YOUR_FILE.dmg"
        echo "Info.plist: <string>$PUBLIC_KEY</string>"
    fi
}

function verify_keys() {
    echo "🔍 验证密钥完整性..."
    
    # 期望的密钥值
    EXPECTED_PRIVATE="ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik="
    EXPECTED_PUBLIC="NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw="
    
    # 从钥匙串获取密钥
    STORED_PRIVATE=$(security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" -w 2>/dev/null)
    STORED_PUBLIC=$(security find-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key" -w 2>/dev/null)
    
    echo ""
    echo "私钥验证:"
    if [ "$STORED_PRIVATE" = "$EXPECTED_PRIVATE" ]; then
        echo "✅ 私钥完整性验证通过"
    else
        echo "❌ 私钥验证失败或不存在"
        echo "期望: $EXPECTED_PRIVATE"
        echo "实际: ${STORED_PRIVATE:-'未找到'}"
    fi
    
    echo ""
    echo "公钥验证:"
    if [ "$STORED_PUBLIC" = "$EXPECTED_PUBLIC" ]; then
        echo "✅ 公钥完整性验证通过"
    else
        echo "❌ 公钥验证失败或不存在"
        echo "期望: $EXPECTED_PUBLIC"
        echo "实际: ${STORED_PUBLIC:-'未找到'}"
    fi
    
    # 验证密钥对匹配性
    if [ -n "$STORED_PRIVATE" ] && [ -n "$STORED_PUBLIC" ]; then
        echo ""
        echo "🔗 验证密钥对匹配性..."
        if command -v ./Frameworks/bin/generate_keys >/dev/null 2>&1; then
            GENERATED_PUBLIC=$(cd Frameworks/bin && echo "$STORED_PRIVATE" | ./generate_keys -p 2>/dev/null)
            if [ "$GENERATED_PUBLIC" = "$STORED_PUBLIC" ]; then
                echo "✅ 密钥对匹配验证通过"
            else
                echo "❌ 密钥对不匹配！"
                echo "从私钥生成的公钥: $GENERATED_PUBLIC"
                echo "存储的公钥: $STORED_PUBLIC"
            fi
        else
            echo "ℹ️  无法验证密钥对匹配性（缺少 generate_keys 工具）"
        fi
    fi
}

function list_keys() {
    echo "📋 列出所有 CiteTrack 相关密钥:"
    echo ""
    
    # 查找所有包含 CiteTrack 的密钥
    security dump-keychain | grep -A 5 -B 5 "CiteTrack" 2>/dev/null || echo "未找到 CiteTrack 相关密钥"
    
    echo ""
    echo "🔍 详细信息:"
    security find-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" 2>/dev/null && echo "✅ 找到私钥条目"
    security find-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key" 2>/dev/null && echo "✅ 找到公钥条目"
}

function remove_keys() {
    echo "⚠️  准备删除 iCloud Keychain 中的 CiteTrack 密钥"
    echo ""
    read -p "确定要删除吗？这会影响所有设备上的密钥！(y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        echo "🗑️  删除密钥..."
        
        security delete-generic-password -a "citetrack_private_key" -s "CiteTrack EdDSA Private Key" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✅ 私钥删除成功"
        else
            echo "ℹ️  私钥删除失败或不存在"
        fi
        
        security delete-generic-password -a "citetrack_public_key" -s "CiteTrack EdDSA Public Key" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✅ 公钥删除成功"
        else
            echo "ℹ️  公钥删除失败或不存在"
        fi
        
        echo "⚠️  密钥删除完成，请重新运行 backup 命令来恢复"
    else
        echo "❌ 取消删除操作"
    fi
}

# 主逻辑
case "$1" in
    backup)
        backup_keys
        ;;
    get)
        get_keys
        ;;
    verify)
        verify_keys
        ;;
    list)
        list_keys
        ;;
    remove)
        remove_keys
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "❌ 未知命令: $1"
        echo ""
        show_help
        exit 1
        ;;
esac