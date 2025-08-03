#!/bin/bash

echo "🔍 开始调试数据管理窗口闪退问题"
echo "⏰ $(date)"

# 启动系统日志监控
echo "📋 启动日志监控..."
log stream --predicate 'process == "CiteTrack"' --level debug > /tmp/citetrack_crash.log 2>&1 &
LOG_PID=$!

# 检查崩溃报告
echo "📊 检查最近的崩溃报告..."
ls -la ~/Library/Logs/DiagnosticReports/CiteTrack* 2>/dev/null | head -5

echo "
🎯 重现步骤:
1. 打开 CiteTrack 应用
2. 进入设置 → 打开数据管理
3. 关闭数据管理窗口 (第一次应该正常)
4. 再次打开数据管理 (第二次应该闪退)

📝 请手动执行上述步骤，完成后按任意键继续分析日志..."
read -p "按回车键继续分析..."

# 停止日志监控
kill $LOG_PID 2>/dev/null

echo "
📋 分析捕获的日志..."
if [ -f /tmp/citetrack_crash.log ]; then
    echo "=== CiteTrack 运行日志 ==="
    cat /tmp/citetrack_crash.log
else
    echo "❌ 未捕获到日志"
fi

echo "
📊 检查新的崩溃报告..."
LATEST_CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/CiteTrack* 2>/dev/null | head -1)
if [ -n "$LATEST_CRASH" ]; then
    echo "🆕 发现最新崩溃报告: $LATEST_CRASH"
    echo "=== 崩溃报告内容 ==="
    cat "$LATEST_CRASH"
else
    echo "❌ 未找到新的崩溃报告"
fi

echo "✅ 调试信息收集完成"