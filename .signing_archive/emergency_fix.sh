#!/bin/bash

# CiteTrack 签名紧急修复脚本
# 当出现 "The update is improperly signed" 错误时使用

echo "🚨 CiteTrack 签名紧急修复脚本"
echo "用于解决 'The update is improperly signed and could not be validated' 错误"
echo ""

# 设置正确的密钥信息
PRIVATE_KEY="ef7vGj/o9yMPlo617hsxOOzDVJOy9r0R/lgYgeIb5Ik="
PUBLIC_KEY="NGyuMsWn3sOkH87MuJA3vvUmg7ZNH/mKt01pvlSqaqw="

echo "🔑 使用的密钥信息:"
echo "私钥: ${PRIVATE_KEY}"
echo "公钥: ${PUBLIC_KEY}"
echo ""

# 检查是否提供了 DMG 文件
if [ $# -eq 0 ]; then
    echo "❌ 使用方法: $0 <DMG文件路径>"
    echo "例如: $0 CiteTrack-v1.2.0.dmg"
    exit 1
fi

DMG_FILE="$1"

# 检查 DMG 文件是否存在
if [ ! -f "$DMG_FILE" ]; then
    echo "❌ DMG 文件不存在: $DMG_FILE"
    exit 1
fi

echo "📦 处理 DMG 文件: $DMG_FILE"

# 获取文件大小
FILE_SIZE=$(wc -c < "$DMG_FILE" | tr -d ' ')
echo "📏 文件大小: $FILE_SIZE bytes"

# 生成签名
echo "🔐 生成 EdDSA 签名..."
SIGNATURE_OUTPUT=$(echo "$PRIVATE_KEY" | ./Frameworks/bin/sign_update "$DMG_FILE")

if [ $? -eq 0 ]; then
    echo "✅ 签名生成成功!"
    echo "$SIGNATURE_OUTPUT"
    
    # 提取签名和长度
    SIGNATURE=$(echo "$SIGNATURE_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="\([^"]*\)"/\1/')
    LENGTH=$(echo "$SIGNATURE_OUTPUT" | grep -o 'length="[^"]*"' | sed 's/length="\([^"]*\)"/\1/')
    
    echo ""
    echo "📋 appcast.xml 更新信息:"
    echo "签名: $SIGNATURE"
    echo "大小: $LENGTH"
    echo ""
    echo "📝 在 appcast.xml 中更新:"
    echo "sparkle:edSignature=\"$SIGNATURE\""
    echo "length=\"$LENGTH\""
    echo ""
    echo "🏗️ 在构建脚本的 Info.plist 中确保包含:"
    echo "<key>SUPublicEDKey</key>"
    echo "<string>$PUBLIC_KEY</string>"
    
else
    echo "❌ 签名生成失败!"
    exit 1
fi

echo ""
echo "✅ 修复完成! 记住要:"
echo "1. 更新 appcast.xml 中的签名和文件大小"
echo "2. 确保应用的 Info.plist 包含正确的 SUPublicEDKey"
echo "3. 重新上传 DMG 到 GitHub Release"
echo "4. 提交并推送 appcast.xml 更改"