#!/bin/bash

# CiteTrack 应用测试脚本
# 测试应用是否能正常启动，不会因为Core Data问题而闪退

# 切换到项目根目录
cd "$(dirname "$0")/.."

APP_NAME="CiteTrack"
APP_BUNDLE="${APP_NAME}.app"

echo "🧪 开始测试 CiteTrack 应用..."

# 检查应用是否存在
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "❌ 找不到应用包: ${APP_BUNDLE}"
    echo "请先运行构建脚本: ./scripts/build_charts.sh"
    exit 1
fi

# 检查可执行文件
if [ ! -f "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" ]; then
    echo "❌ 找不到可执行文件: ${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
    exit 1
fi

# 检查Core Data模型文件
echo "🔍 检查Core Data模型文件..."
if [ -d "${APP_BUNDLE}/Contents/Resources/CitationTrackingModel.momd" ]; then
    echo "✅ 找到编译后的Core Data模型"
elif [ -d "${APP_BUNDLE}/Contents/Resources/CitationTrackingModel.xcdatamodeld" ]; then
    echo "✅ 找到源Core Data模型"
else
    echo "❌ 找不到Core Data模型文件"
    echo "📁 Resources目录内容:"
    ls -la "${APP_BUNDLE}/Contents/Resources/"
    exit 1
fi

# 启动应用进行测试
echo "🚀 启动应用进行测试..."
echo "⚠️  应用将在后台运行10秒进行测试"
echo "📝 请查看控制台输出是否有错误信息"

# 在后台启动应用
"${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" &
APP_PID=$!

# 等待10秒
sleep 10

# 检查应用是否还在运行
if kill -0 $APP_PID 2>/dev/null; then
    echo "✅ 应用正常启动，没有闪退"
    echo "🛑 停止测试应用..."
    kill $APP_PID
    wait $APP_PID 2>/dev/null
else
    echo "❌ 应用启动失败或已闪退"
    echo "📝 请检查系统日志获取详细错误信息:"
    echo "   log show --predicate 'process == \"CiteTrack\"' --last 1m"
    exit 1
fi

echo "✅ 测试完成！应用可以正常启动。" 