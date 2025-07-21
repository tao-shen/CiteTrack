#!/bin/bash

echo "🔍 开始监控 CiteTrack 闪退问题"
echo "⏰ $(date)"
echo ""

# 清理旧的监控文件
rm -f /tmp/citetrack_monitor.log
rm -f /tmp/citetrack_crash_dump.log

# 启动系统日志监控（后台运行）
echo "📋 启动系统日志监控..."
(log stream --predicate 'process CONTAINS "CiteTrack"' --style compact 2>/dev/null | while read line; do
    echo "$(date '+%H:%M:%S'): $line" >> /tmp/citetrack_monitor.log
done) &
LOG_PID=$!

# 启动进程监控（后台运行）
echo "📊 启动进程监控..."
(while true; do
    CITETRACK_PID=$(pgrep -f CiteTrack)
    if [ -n "$CITETRACK_PID" ]; then
        echo "$(date '+%H:%M:%S'): CiteTrack running (PID: $CITETRACK_PID)" >> /tmp/citetrack_monitor.log
        sleep 1
    else
        echo "$(date '+%H:%M:%S'): CiteTrack process not found - may have crashed" >> /tmp/citetrack_monitor.log
        break
    fi
done) &
PROC_PID=$!

# 启动CiteTrack应用
echo "🚀 启动 CiteTrack..."
open CiteTrack.app
sleep 2

# 等待用户操作
echo ""
echo "✅ 监控已启动"
echo "📝 现在请执行以下步骤："
echo "   1. 打开设置窗口"
echo "   2. 点击'打开数据管理'"
echo "   3. 关闭数据管理窗口 (第一次)"
echo "   4. 再次点击'打开数据管理'"
echo "   5. 关闭数据管理窗口 (第二次 - 应该闪退)"
echo ""
echo "⏳ 等待用户操作... 按任意键停止监控"
read -t 60 -n 1

# 停止监控
echo ""
echo "🛑 停止监控..."
kill $LOG_PID 2>/dev/null
kill $PROC_PID 2>/dev/null

# 检查crash报告
echo "📊 检查最新crash报告..."
LATEST_CRASH=$(find ~/Library/Logs/DiagnosticReports -name "CiteTrack*" -newermt "$(date -v-2M '+%Y-%m-%d %H:%M:%S')" 2>/dev/null | sort | tail -1)

echo ""
echo "=== 监控日志 ==="
if [ -f /tmp/citetrack_monitor.log ]; then
    cat /tmp/citetrack_monitor.log
else
    echo "❌ 未捕获到监控日志"
fi

echo ""
echo "=== Crash 报告 ==="
if [ -n "$LATEST_CRASH" ]; then
    echo "🆕 发现crash报告: $LATEST_CRASH"
    echo "📄 报告摘要:"
    head -100 "$LATEST_CRASH" | grep -E "(exception|termination|lastExceptionBacktrace)" || echo "无异常信息摘要"
else
    echo "❌ 未找到新的crash报告"
fi

echo ""
echo "✅ 监控完成"