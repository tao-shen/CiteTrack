#!/bin/bash

echo "🧪 CiteTrack 崩溃修复测试"
echo "========================================"

# 检查应用是否存在
if [ ! -d "CiteTrack.app" ]; then
    echo "❌ CiteTrack.app 不存在，请先构建应用"
    exit 1
fi

echo "📱 启动应用进行崩溃测试..."

# 启动应用
open CiteTrack.app

echo "⏳ 等待应用启动..."
sleep 3

echo "🔍 检查应用是否正在运行..."
if pgrep -f "CiteTrack" > /dev/null; then
    echo "✅ 应用成功启动，未发生启动崩溃"
    
    echo "📋 测试步骤："
    echo "1. 应用应该显示在菜单栏"
    echo "2. 点击菜单栏图标应该显示菜单"
    echo "3. 点击'偏好设置'打开设置窗口"
    echo "4. 点击'添加学者'按钮"
    echo "5. 在输入框中测试复制粘贴功能 (Cmd+C/V/A)"
    echo "6. 尝试添加学者后关闭窗口"
    echo "7. 重复几次添加操作"
    echo "8. 最后退出应用"
    
    echo ""
    echo "🎯 关键修复点："
    echo "• 修复了异步回调中的NSAlert崩溃"
    echo "• 添加了窗口存在性检查"
    echo "• 改进了内存管理和对象清理"
    echo "• 修复了启动时序问题"
    echo "• 增强了错误处理"
    
    echo ""
    echo "⚠️  如果应用崩溃，请检查控制台日志："
    echo "   Console.app -> 崩溃报告 -> CiteTrack"
    
    echo ""
    echo "✅ 测试完成后，应用应该能够："
    echo "   • 正常启动不崩溃"
    echo "   • 支持完整的复制粘贴操作"
    echo "   • 添加学者后不崩溃"
    echo "   • 正常退出不崩溃"
    
else
    echo "❌ 应用启动失败或立即崩溃"
    echo "🔍 检查崩溃日志："
    echo "   打开 Console.app"
    echo "   查看 '崩溃报告' 部分"
    echo "   寻找 CiteTrack 相关的崩溃报告"
fi

echo ""
echo "🏁 测试脚本完成"
echo "========================================" 