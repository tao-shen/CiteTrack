#!/bin/bash

# CiteTrack 安全警告绕过脚本
# 用于解决 "Apple could not verify CiteTrack is free of malware" 错误

# 切换到项目根目录
cd "$(dirname "$0")/.."

echo "🔓 CiteTrack 安全警告绕过工具"
echo "================================"
echo ""

# 检查应用是否存在
if [ ! -d "CiteTrack.app" ]; then
    echo "❌ 错误: 找不到 CiteTrack.app"
    echo "请确保已构建应用程序"
    exit 1
fi

echo "📱 找到 CiteTrack.app"
echo ""

# 方法 1: 移除隔离属性
echo "🛠️  方法 1: 移除隔离属性"
echo "正在移除 macOS 隔离标记..."

xattr -dr com.apple.quarantine CiteTrack.app 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ 隔离属性已移除"
else
    echo "⚠️  隔离属性移除失败或不存在"
fi

echo ""

# 方法 2: 验证当前状态
echo "🔍 验证应用状态"
echo "检查代码签名..."

codesign -dv CiteTrack.app 2>&1 | head -5

echo ""
echo "检查 Gatekeeper 评估..."

spctl --assess --type exec CiteTrack.app 2>&1

echo ""

# 提供用户指导
echo "📋 如果应用仍然无法运行，请尝试以下方法："
echo ""
echo "方法 A - 右键打开:"
echo "1. 右键点击 CiteTrack.app"
echo "2. 选择 '打开'"
echo "3. 在弹出对话框中点击 '打开'"
echo ""
echo "方法 B - 系统设置:"
echo "1. 打开 '系统偏好设置' → '安全性与隐私'"
echo "2. 在 '通用' 标签页中找到被阻止的应用"
echo "3. 点击 '仍要打开'"
echo ""
echo "方法 C - 终端运行:"
echo "open CiteTrack.app"
echo ""

# 尝试直接启动应用
echo "🚀 尝试启动 CiteTrack..."
open CiteTrack.app

if [ $? -eq 0 ]; then
    echo "✅ CiteTrack 启动成功！"
    echo ""
    echo "🎉 如果应用正常运行，说明安全警告已解决"
    echo "您可以将 CiteTrack.app 移动到 /Applications 文件夹中"
else
    echo "❌ 自动启动失败"
    echo "请手动尝试上述方法 A、B 或 C"
fi

echo ""
echo "💡 提示: 这是一个安全的应用，使用 ad-hoc 签名"
echo "如需完全消除警告，开发者需要购买 Apple Developer Program ($99/年)" 