#!/bin/bash

echo "🧪 CiteTrack 添加学者功能测试"
echo "========================================"

# 检查应用是否存在
if [ ! -d "CiteTrack.app" ]; then
    echo "❌ CiteTrack.app 不存在，请先构建应用"
    exit 1
fi

echo "📱 启动应用..."

# 确保没有旧的进程
pkill -f "CiteTrack" 2>/dev/null || true
sleep 1

# 启动应用
open CiteTrack.app

echo "⏳ 等待应用启动..."
sleep 3

echo "🔍 检查应用是否正在运行..."
if pgrep -f "CiteTrack" > /dev/null; then
    echo "✅ 应用成功启动"
    
    echo ""
    echo "🎯 关键修复内容："
    echo "• 完全移除了复杂的模态窗口管理"
    echo "• 不再使用 objc_setAssociatedObject"
    echo "• 使用简单的 NSAlert + accessoryView 方式"
    echo "• 保持了 EditableTextField 的复制粘贴功能"
    echo "• 消除了内存管理问题"
    
    echo ""
    echo "📋 手动测试步骤："
    echo "1. 点击菜单栏的 ∞ 图标"
    echo "2. 选择 '偏好设置...'"
    echo "3. 点击 '添加学者' 按钮"
    echo "4. 在弹出的对话框中："
    echo "   - 测试复制粘贴功能 (Cmd+C/V/A)"
    echo "   - 输入测试ID: 'test123'"
    echo "   - 输入测试姓名: '测试学者'"
    echo "   - 点击 '添加' 按钮"
    echo "5. 应用应该不会崩溃"
    echo "6. 重复几次添加操作"
    echo "7. 关闭设置窗口"
    echo "8. 退出应用"
    
    echo ""
    echo "✅ 预期结果："
    echo "• 对话框正常显示"
    echo "• 输入框支持完整的键盘操作"
    echo "• 添加操作不会导致崩溃"
    echo "• 应用可以正常退出"
    
    echo ""
    echo "⚠️  如果仍然崩溃，请："
    echo "1. 打开 Console.app"
    echo "2. 查看崩溃报告"
    echo "3. 报告具体的崩溃信息"
    
    echo ""
    echo "🔧 技术改进："
    echo "• 移除了所有 objc_setAssociatedObject 调用"
    echo "• 简化了窗口生命周期管理"
    echo "• 使用标准的 NSAlert 模态对话框"
    echo "• 保持了自定义 EditableTextField 类"
    echo "• 增强了异步回调的安全性"
    
else
    echo "❌ 应用启动失败或立即崩溃"
    echo ""
    echo "🔍 故障排除："
    echo "1. 检查 Console.app 中的崩溃报告"
    echo "2. 查看系统日志中的错误信息"
    echo "3. 确认应用签名和权限设置"
fi

echo ""
echo "🏁 测试脚本完成"
echo "========================================" 