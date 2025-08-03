#!/bin/bash

# CiteTrack iOS 快速启动脚本
# 作者: Claude
# 日期: $(date '+%Y-%m-%d')

echo "🚀 CiteTrack iOS 快速启动"
echo "========================="

# 检查是否在正确的目录
if [ ! -f "CiteTrack.xcodeproj/project.pbxproj" ]; then
    echo "❌ 错误: 请在 iOS 项目目录中运行此脚本"
    echo "   当前目录: $(pwd)"
    echo "   应该在: /Users/tao.shen/google_scholar_plugin/iOS"
    exit 1
fi

# 检查 Xcode 是否安装
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 Xcode"
    echo "   请从 App Store 安装 Xcode"
    exit 1
fi

# 显示项目信息
echo "📱 项目信息:"
echo "   项目名称: CiteTrack"
echo "   平台: iOS 15.0+"
echo "   语言: Swift"
echo "   UI框架: SwiftUI"

# 检查连接的设备
echo ""
echo "🔍 检查连接的设备..."
devices=$(xcrun xctrace list devices 2>/dev/null | grep -E "iPhone|iPad" | grep -v "Simulator")

if [ -z "$devices" ]; then
    echo "⚠️  未检测到连接的 iOS 设备"
    echo "   请确保:"
    echo "   1. iPhone 已通过 USB 连接到 Mac"
    echo "   2. iPhone 已解锁并信任此电脑"
    echo "   3. iPhone iOS 版本为 15.0 或更高"
else
    echo "✅ 检测到连接的设备:"
    echo "$devices"
fi

# 打开 Xcode 项目
echo ""
echo "🛠️  打开 Xcode 项目..."
open CiteTrack.xcodeproj

echo ""
echo "📋 接下来的步骤:"
echo "   1. 在 Xcode 中配置签名 (Signing & Capabilities)"
echo "   2. 选择您的 Apple ID Team"
echo "   3. 修改 Bundle Identifier 为唯一值"
echo "   4. 选择连接的 iPhone 设备"
echo "   5. 点击 Run 按钮 (▶️) 编译和安装"

echo ""
echo "📖 详细安装指南请查看: iOS_INSTALLATION_GUIDE.md"
echo ""
echo "🎉 准备就绪! Xcode 即将打开项目..."