#!/bin/bash

echo "🧪 CiteTrack 复制粘贴功能测试"
echo "================================"
echo ""
echo "测试步骤："
echo "1. 启动 CiteTrack 应用"
echo "2. 点击菜单栏的 ∞ 图标"
echo "3. 选择 '偏好设置...'"
echo "4. 点击 '添加学者' 按钮"
echo "5. 在弹出的对话框中测试以下功能："
echo ""
echo "   📋 复制粘贴测试："
echo "   • 在第一个输入框中输入一些文字"
echo "   • 使用 Cmd+A 全选文字"
echo "   • 使用 Cmd+C 复制文字"
echo "   • 使用 Cmd+V 粘贴到第二个输入框"
echo "   • 使用 Cmd+X 剪切文字"
echo ""
echo "   ⌨️  键盘快捷键测试："
echo "   • Cmd+A (全选)"
echo "   • Cmd+C (复制)"
echo "   • Cmd+V (粘贴)"
echo "   • Cmd+X (剪切)"
echo "   • Cmd+Z (撤销)"
echo ""
echo "预期结果："
echo "✅ 所有键盘快捷键都应该正常工作"
echo "✅ 可以在两个输入框之间复制粘贴文字"
echo "✅ 可以从其他应用复制文字并粘贴到输入框"
echo ""

# 启动应用进行测试
echo "正在启动 CiteTrack 进行测试..."
open CiteTrack.app

echo ""
echo "⏳ 请手动测试复制粘贴功能，然后按任意键继续..."
read -n 1 -s

echo ""
echo "测试完成！如果所有功能都正常工作，说明复制粘贴问题已解决。" 