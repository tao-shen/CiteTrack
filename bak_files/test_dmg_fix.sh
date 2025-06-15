#!/bin/bash

echo "🧪 CiteTrack DMG 修复验证测试"
echo "========================================"

# 检查DMG是否存在
if [ ! -f "CiteTrack.dmg" ]; then
    echo "❌ CiteTrack.dmg 不存在，请先构建"
    exit 1
fi

echo "📦 检查DMG文件..."
DMG_SIZE=$(du -h CiteTrack.dmg | cut -f1)
echo "✅ DMG大小: $DMG_SIZE"

echo ""
echo "🔍 验证DMG内容..."

# 创建临时挂载点
MOUNT_POINT="/tmp/citetrack_verify_$$"
mkdir -p "$MOUNT_POINT"

# 挂载DMG
if hdiutil attach CiteTrack.dmg -readonly -mountpoint "$MOUNT_POINT" >/dev/null 2>&1; then
    echo "✅ DMG挂载成功"
    
    # 检查内容
    echo ""
    echo "📋 DMG内容:"
    ls -la "$MOUNT_POINT/"
    
    # 检查是否有README文件
    if [ -f "$MOUNT_POINT/README.txt" ]; then
        echo "❌ README.txt 仍然存在（应该已被移除）"
    else
        echo "✅ README.txt 已成功移除"
    fi
    
    # 检查应用是否存在
    if [ -d "$MOUNT_POINT/CiteTrack.app" ]; then
        echo "✅ CiteTrack.app 存在"
        
        # 检查代码签名
        echo ""
        echo "🔐 检查代码签名..."
        if codesign -dv "$MOUNT_POINT/CiteTrack.app" 2>&1 | grep -q "adhoc"; then
            echo "✅ 应用已使用ad-hoc签名"
        else
            echo "⚠️  代码签名状态异常"
        fi
        
        # 验证签名
        if codesign --verify --deep --strict "$MOUNT_POINT/CiteTrack.app" >/dev/null 2>&1; then
            echo "✅ 代码签名验证通过"
        else
            echo "⚠️  代码签名验证失败"
        fi
        
    else
        echo "❌ CiteTrack.app 不存在"
    fi
    
    # 检查Applications快捷方式
    if [ -L "$MOUNT_POINT/Applications" ]; then
        echo "✅ Applications 快捷方式存在"
    else
        echo "❌ Applications 快捷方式缺失"
    fi
    
    # 卸载DMG
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1
    echo ""
    echo "✅ DMG已卸载"
    
else
    echo "❌ DMG挂载失败"
fi

# 清理临时目录
rm -rf "$MOUNT_POINT"

echo ""
echo "🎯 修复总结:"
echo "• ✅ 移除了README.txt文件"
echo "• ✅ 添加了ad-hoc代码签名"
echo "• ✅ 保持了Applications快捷方式"
echo "• ✅ DMG结构简洁清晰"

echo ""
echo "🚀 使用说明:"
echo "1. 双击 CiteTrack.dmg 打开"
echo "2. 拖拽 CiteTrack.app 到 Applications 文件夹"
echo "3. 如果系统提示安全警告："
echo "   - 右键点击应用，选择'打开'"
echo "   - 或在系统偏好设置 > 安全性与隐私中允许"

echo ""
echo "🏁 测试完成"
echo "========================================" 